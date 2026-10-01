"""Package an already native-smoke-tested v41 Windows executable; no source edits."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

SOURCE = "93674fdb64dc1251e4de0d991cd34b47422576fe"
TREE = "b82ec298d4e860569e9436979b6b2a517df8bd90"
CHUNK = 24 * 1024 * 1024
README = """Loop Conquest v41 — Windows 플레이 빌드

실행
1. ZIP 전체를 새 폴더에 풉니다.
2. 이전 게임을 종료하고 LoopConquest.exe를 엽니다.
Godot나 Python 설치가 필요하지 않습니다. 기존 저장 폴더를 그대로 사용합니다.
이 빌드는 서명되지 않은 개발용 실행 파일입니다.

이번 변경
- 적 5종의 구별되는 몸체, 간결한 HUD와 정확한 성장 설명
- 사원 상부 가림 처리, 결과 정산/다음 행동 안내
- 야영지와 일시정지의 음량·음소거·창/전체화면 설정
- 수로도시 통합 시안과 사원 대표 환경
일반 성장 상한·가격은 기존 기준입니다. 별도 실험은 켜져 있지 않습니다.

확인할 것
1. 사원에서 이동·공격·회피와 적 역할을 읽을 수 있는가
2. 건물 뒤에서 화면 전환과 가림이 덜 산만한가
3. 카드 선택과 정산 뒤 구매·장착·재출정이 이해되는가
4. 설정의 소리와 창 전환이 실제 컴퓨터에서 정상인가
5. 야영지의 수로도시 시험에서 시장·창고·수변의 차이가 느껴지는가

검증 범위
Windows runner에서 이 실행 파일의 야영지 시작/정상 종료를 확인했습니다.
실제 GPU·소리·장시간 플레이·재미·최종 아트 수용은 별도 플레이 확인 대상입니다.
"""


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = json.loads(args.report.read_text(encoding="utf-8"))
    assert report["status"] == "passed" and report["source_commit"] == SOURCE
    assert report["executable"]["sha256"] == sha(args.executable)
    assert report["startup"]["exit_code"] == 0
    args.output.mkdir(parents=True, exist_ok=False)
    archive = args.output / "LoopConquest-v41-Windows.zip"
    # The receipt intentionally excludes runner-specific filesystem locations.
    receipt = {"source_commit": SOURCE, "source_tree": TREE,
               "godot": report["godot"], "executable": report["executable"],
               "startup": {k: v for k, v in report["startup"].items()
                           if k != "isolated_user_data"},
               "release_contents": report["release_contents"], "scope": report["scope"]}
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        bundle.write(args.executable, "LoopConquest-v41/LoopConquest.exe")
        bundle.writestr("LoopConquest-v41/README_KO.txt", README.encode("utf-8-sig"))
        bundle.writestr("LoopConquest-v41/build.json", json.dumps(receipt, indent=2) + "\n")
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None
        assert hashlib.sha256(bundle.read("LoopConquest-v41/LoopConquest.exe")).hexdigest() == report["executable"]["sha256"]
    # Transfer parts each fit the connector's 32MiB local download limit.
    assert CHUNK < archive.stat().st_size <= 2 * CHUNK, "Revisit fixed artifact-part count"
    parts_dir = args.output / "parts"
    parts_dir.mkdir()
    parts = []
    with archive.open("rb") as stream:
        for number in (1, 2):
            part = parts_dir / f"part-{number:02}"
            part.write_bytes(stream.read(CHUNK))
            parts.append({"name": part.name, "bytes": part.stat().st_size, "sha256": sha(part)})
        assert stream.read(1) == b""
    manifest = {**receipt, "archive": {"name": archive.name, "bytes": archive.stat().st_size,
                                       "sha256": sha(archive)}, "parts": parts}
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
