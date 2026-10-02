"""Build an isolated, ad-hoc-signed macOS field preview on a hosted Mac.

Official Godot archives are SHA-512 checked. Startup is headless on the runner,
not a claim about the user's Mac, Gatekeeper, graphics, sound or play acceptance.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import time
import urllib.request
import zipfile
from windows_export_smoke import verify_release_contents

VERSION = "4.6-stable"
BASE = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}"
EDITOR = f"Godot_v{VERSION}_macos.universal.zip"
TEMPLATES = f"Godot_v{VERSION}_export_templates.tpz"
ERROR = re.compile(r"(?m)^\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:|FAIL:)")


def digest(path, algorithm):
    with Path(path).open("rb") as handle:
        return hashlib.file_digest(handle, algorithm).hexdigest()


def checked(command, cwd, log, timeout=180, env=None):
    started = time.monotonic()
    result = subprocess.run([str(x) for x in command], cwd=cwd, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=timeout, text=True, errors="replace")
    log.write_text(result.stdout, encoding="utf-8")
    if result.returncode or ERROR.search(result.stdout):
        raise RuntimeError(f"Process/log failure ({result.returncode}): {log.name}")
    return {"exit_code": result.returncode, "seconds": round(time.monotonic() - started, 3)}


def smoke(workspace, scratch, output, commit, label, architecture, report):
    if sys.platform != "darwin":
        raise RuntimeError("This workflow must run on macOS; cross-export is not this smoke test")
    if scratch.exists():
        raise RuntimeError("Refusing to reuse scratch files or previous exports")
    scratch.mkdir(parents=True)
    output.mkdir(parents=True, exist_ok=True)
    downloads = scratch / "downloads"
    downloads.mkdir()
    sums = urllib.request.urlopen(BASE + "/SHA512-SUMS.txt", timeout=60).read().decode()
    checksums = {}
    for line in sums.splitlines():
        fields = line.split()
        if len(fields) >= 2:
            checksums[fields[-1].lstrip("*")] = fields[0]

    def download(name):
        if name not in checksums:
            raise RuntimeError(f"Official checksum missing: {name}")
        path = downloads / name
        with urllib.request.urlopen(BASE + "/" + name, timeout=180) as response, path.open("wb") as dest:
            shutil.copyfileobj(response, dest, length=8 * 1024 * 1024)
        if digest(path, "sha512") != checksums[name]:
            raise RuntimeError(f"Official checksum mismatch: {name}")
        return name

    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(download, [EDITOR, TEMPLATES]))
    report["official_archives"] = {name: {"sha512": checksums[name], "bytes": (downloads / name).stat().st_size} for name in [EDITOR, TEMPLATES]}
    editor_dir = scratch / "editor"
    checked(["ditto", "-x", "-k", downloads / EDITOR, editor_dir], scratch, output / "editor-extract.log")
    editor = editor_dir / "Godot.app/Contents/MacOS/Godot"
    if not editor.is_file():
        raise RuntimeError("Official editor executable not found")
    template_dir = Path.home() / "Library/Application Support/Godot/export_templates/4.6.stable"
    template_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(downloads / TEMPLATES) as archive:
        with archive.open("templates/macos.zip") as source, (template_dir / "macos.zip").open("wb") as dest:
            shutil.copyfileobj(source, dest)

    # These two packaging-only edits occur in the ephemeral checkout.
    project = workspace / "project.godot"
    text = project.read_text()
    old = 'config/custom_user_dir_name="Godot/app_userdata/Loop Conquest - 1G Complete Run v03"'
    if text.count(old) != 1:
        raise RuntimeError("Unexpected original save-path contract")
    title = f"Loop Conquest - {label} Field Preview"
    text = re.sub(r'^config/name="[^"]+"$', f'config/name="{title}"', text, count=1, flags=re.M)
    text = text.replace(old, 'config/custom_user_dir_name="LoopConquest-FieldPreview-v44"')
    old_main = 'run/main_scene="res://game/travel_camp.tscn"'
    if text.count(old_main) != 1:
        raise RuntimeError("Unexpected ordinary main-scene contract")
    text = text.replace(old_main, 'run/main_scene="res://game/field_preview_entry.tscn"')
    project.write_text(text)
    presets = workspace / "export_presets.cfg"
    config = presets.read_text()
    config = config.replace('application/bundle_identifier="com.noru358.loopconquest1a"',
                            'application/bundle_identifier="com.noru358.loopconquest.preview.v44"', 1)
    # Official 4.6 macOS templates contain the universal binary only.
    # Produce that valid bundle first, then thin/re-sign on this native Mac when requested.
    config = config.replace('binary_format/architecture="universal"', 'binary_format/architecture="universal"', 1)
    presets.write_text(config)
    report["packaging_changes"] = {"title": title, "separate_user_data": "LoopConquest-FieldPreview-v44", "bundle_id": "com.noru358.loopconquest.preview.v44", "source_commit": commit, "entry": "res://game/field_preview_entry.tscn"}
    checked([editor, "--headless", "--editor", "--path", workspace, "--quit"], scratch, output / "import.log", 240)
    deployment = scratch / "deployment"
    deployment.mkdir()
    app = deployment / f"Loop Conquest - {label}.app"
    checked([editor, "--headless", "--verbose", "--path", workspace,
             "--export-release", "macOS", app], scratch, output / "export.log", 300)
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
    if architecture == "arm64":
        thin = executable.with_name(executable.name + ".arm64")
        checked(["lipo", executable, "-thin", "arm64", "-output", thin], deployment, output / "thin-arm64.log")
        thin.chmod(executable.stat().st_mode)
        thin.replace(executable)
        checked(["codesign", "--force", "--deep", "--sign", "-", "--preserve-metadata=identifier,entitlements,flags", app],
                deployment, output / "codesign-arm64.log")
    architectures = subprocess.check_output(["lipo", "-archs", str(executable)], text=True).strip().split()
    if set(architectures) != ({"arm64", "x86_64"} if architecture == "universal" else {"arm64"}):
        raise RuntimeError(f"Expected {architecture} binary, got {architectures}")
    checked(["codesign", "--verify", "--deep", "--strict", app], deployment, output / "codesign-verify.log")
    report["architectures"] = architectures
    report["ad_hoc_signature_verified"] = True
    report["notarized"] = False
    export_text = (output / "export.log").read_text()
    packed = set(re.findall(r"Storing File: (res://[^\r\n\x1b]+)", export_text))
    if not packed or any(x.startswith(("res://docs/", "res://tests/", "res://scripts/")) for x in packed):
        raise RuntimeError("Missing pack evidence or development source leaked into pack")
    report["packed_resource_count"] = len(packed)
    report["release_contents"] = verify_release_contents(workspace, export_text)
    if (deployment / "project.godot").exists():
        raise RuntimeError("Release smoke must not use a loose project")
    # Resolve each requested scene's actual remapped name from Godot's export cache.
    aliases = {}
    for cache in (workspace / ".godot/exported").glob("*/file_cache"):
        for line in cache.read_text().splitlines():
            fields = line.split("::")
            if len(fields) == 4:
                aliases.setdefault(fields[0], []).append(fields[3])
    report["startup"] = []
    for name, scene in [("camp", "res://game/travel_camp.tscn"),
                        ("temple-circuit", "res://game/temple_circuit_run.tscn"),
                        ("jungle-south", "res://game/jungle_south_circuit.tscn"),
                        ("deep-wetland", "res://game/deep_wetland_trial.tscn")]:
        engine_log = output / f"{name}-engine.log"
        command = [executable, "--headless", "--verbose", "--max-fps", "60", "--quit-after", "120", "--log-file", engine_log]
        if name != "camp": command.extend(["--", "--preview-scene=" + name])
        result = checked(command, deployment, output / f"{name}-process.log", 90)
        contents = engine_log.read_text(errors="replace")
        if ERROR.search(contents): raise RuntimeError(f"Exported scene error: {name}")
        actual = next((path for path in [scene] + aliases.get(scene, []) if f"Loading resource: {path}" in contents), None)
        if not actual: raise RuntimeError(f"Requested packed scene was not loaded: {scene}")
        result.update({"scene": scene, "loaded_resource": actual, "headless_runner_only": True})
        report["startup"].append(result)
    expected_data = Path.home() / "Library/Application Support/LoopConquest-FieldPreview-v44"
    if not expected_data.is_dir():
        raise RuntimeError("Expected separate preview user-data directory was not created")
    report["verified_user_data_directory"] = str(expected_data)
    archive = output / f"LoopConquest-{label}-macOS-{architecture}.zip"
    checked(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app, archive], deployment, output / "package.log", 240)
    report["package"] = {"name": archive.name, "bytes": archive.stat().st_size, "sha256": digest(archive, "sha256")}
    # A native compressed disk image avoids chat attachment limits without splitting files.
    # Validate Apple's available format locally and verify the mounted app, not only the container.
    formats = subprocess.check_output(["hdiutil", "create", "-help"], stderr=subprocess.STDOUT, text=True)
    if "ULMO" not in formats:
        raise RuntimeError("Native hdiutil does not advertise the required LZMA format")
    image = output / f"LoopConquest-{label}-macOS-{architecture}.dmg"
    checked(["hdiutil", "create", "-srcfolder", deployment, "-volname", f"Loop Conquest {label}",
             "-format", "ULMO", image], scratch, output / "dmg-create.log", 300)
    checked(["hdiutil", "verify", image], scratch, output / "dmg-verify.log", 120)
    mount = scratch / "mounted-preview"
    checked(["hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", mount, image],
            scratch, output / "dmg-attach.log", 120)
    try:
        mounted_app = mount / app.name
        mounted_executable = mounted_app / "Contents/MacOS" / info["CFBundleExecutable"]
        if digest(mounted_executable, "sha256") != digest(executable, "sha256"):
            raise RuntimeError("Mounted image executable differs from verified export")
        checked(["codesign", "--verify", "--deep", "--strict", mounted_app], scratch, output / "dmg-signature.log")
        checked([mounted_executable, "--headless", "--quit-after", "120"],
                scratch, output / "dmg-startup.log", 90)
    finally:
        checked(["hdiutil", "detach", mount], scratch, output / "dmg-detach.log", 120)
    report["disk_image"] = {"name": image.name, "bytes": image.stat().st_size,
                            "sha256": digest(image, "sha256"), "format": "ULMO",
                            "mounted_signature_and_startup_verified": True}
    report["status"] = "passed"
    (output / "PLAYTEST.txt").write_text(
        f"Loop Conquest {label} 필드 비교판\n소스: {commit}\n\n"
        "압축을 풀고 .app을 실행하세요. 기존 v43와 별도 저장을 사용합니다.\n"
        "야영지 → 발견 탭 아래에서 사원 4분 진행 / 정글 남쪽 순환 / 깊은 사원 습지 시험을 선택할 수 있습니다.\n"
        "정글 시험은 진입용 해금이 있는 별도 개발 기록으로 시작합니다. 습지는 저장·보상 없는 대표 구간입니다.\n"
        "첫 권역 전체 완성판이 아닙니다. 정상속도 재미·미감·장시간 성능은 별도 확인이 필요합니다.\n"
        "검증 범위: 공식 Godot, 요청 아키텍처, ad-hoc 서명, Mac CI headless에서 앱과 네 씬 초기 실행.\n"
        "사용자 Mac에서의 GUI 첫 실행, Gatekeeper, 사운드와 GPU 플레이는 아직 미검증이며 notarization은 없습니다.\n",
        encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--scratch", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--architecture", choices=["universal", "arm64"], default="universal")
    args = parser.parse_args()
    if not re.fullmatch(r"v[0-9]+(?:\.[0-9]+)?", args.label): parser.error("Invalid preview label")
    if not re.fullmatch(r"[0-9a-f]{40}", args.commit): parser.error("Expected full source SHA")
    args.output.mkdir(parents=True, exist_ok=True)
    report = {"status": "failed", "source_commit": args.commit, "label": args.label,
              "scope": "Hosted macOS headless exported-app startup; not user-device or gameplay acceptance"}
    try:
        smoke(args.workspace.resolve(), args.scratch.resolve(), args.output.resolve(), args.commit, args.label, args.architecture, report)
    except Exception as error:
        report["error"] = str(error)
        raise
    finally:
        (args.output / "manifest.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")

if __name__ == "__main__":
    main()
