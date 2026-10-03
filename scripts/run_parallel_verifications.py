#!/usr/bin/env python3
"""Run the complete headless inventory in two isolated, sequential batches (Linux).

The actor-depth fixture remains a dedicated rendered CI step. Each batch imports
its own byte-copy project once. Each fixture gets fresh user directories; restart
children inherit those directories. Logs/manifests survive failures and staging
cleanup. This is isolation for trusted tests, not a security sandbox.
"""
from __future__ import annotations

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

DEDICATED = "tests/verify_actor_terrain_depth.gd"
ERROR = re.compile(r"SCRIPT ERROR:|Parse Error:|^FAIL:", re.MULTILINE)
OWNER = ".parallel-verifications-owner.json"
USER_DIRS = ("HOME", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME",
             "XDG_STATE_HOME", "XDG_RUNTIME_DIR", "XDG_DATA_DIRS", "XDG_CONFIG_DIRS",
             "TMPDIR", "TMP", "TEMP")
EXCLUDED = {".git", ".godot", "__pycache__", "verification-logs", "measurements",
            "build", "dist", "exports"}


def dump(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def inventory(source: Path) -> tuple[list[str], list[list[str]]]:
    found = sorted(p.relative_to(source).as_posix() for p in (source / "tests").glob("verify_*.gd") if p.is_file())
    if DEDICATED not in found or len(found) < 3:
        raise ValueError("Expected actor-depth dedicated fixture and at least two headless fixtures")
    headless = [name for name in found if name != DEDICATED]
    manifests = [headless[::2], headless[1::2]]
    check_coverage(headless, [name for batch in manifests for name in batch])
    return found, manifests


def check_coverage(expected: list[str], actual: list[str]) -> None:
    if len(set(expected)) != len(expected) or Counter(expected) != Counter(actual):
        raise ValueError(f"Missing, duplicate or unexpected coverage: expected={expected}, actual={actual}")


def private_env(root: Path) -> dict[str, str]:
    # Optional capture/report output must never target inherited caller paths.
    env = {key: value for key, value in os.environ.items()
           if not key.startswith("XDG_") and not any(word in key for word in ("CAPTURE", "REPORT", "OUTPUT"))}
    for key in USER_DIRS:
        path = root / key.lower()
        path.mkdir(parents=True, mode=0o700)
        env[key] = str(path.resolve())
    env["GODOT_SILENCE_ROOT_WARNING"] = "1"
    return env


def copy_project(source: Path, target: Path) -> None:
    def ignore(folder: str, names: list[str]) -> list[str]:
        ignored = [name for name in names if name in EXCLUDED or name.endswith((".log", ".tmp", ".pyc"))]
        for name in set(names) - set(ignored):
            if (Path(folder) / name).is_symlink():
                raise ValueError(f"Project symlink not supported: {Path(folder) / name}")
        return ignored
    shutil.copytree(source, target, ignore=ignore, copy_function=shutil.copy2)


def run_engine(godot: str, project: Path, env: dict[str, str], options: list[str],
               log: Path, timeout: float) -> dict:
    started = time.monotonic()
    result = {"status": "failed", "exit_code": None, "timeout": False, "log": log.name}
    with log.open("w") as stream:
        try:
            process = subprocess.Popen([godot, "--headless", "--path", str(project), *options],
                                       cwd=project, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            try:
                result["exit_code"] = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                result["timeout"] = True
            finally:
                # Include restart descendants, even when their parent exits first.
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait()
        except OSError as exc:
            stream.write(f"Runner could not launch engine: {exc}\n")
            result["error"] = str(exc)
    result["error_text"] = bool(ERROR.search(log.read_text(errors="replace")))
    result["duration_seconds"] = round(time.monotonic() - started, 3)
    if result["exit_code"] == 0 and not result["timeout"] and not result["error_text"]:
        result["status"] = "passed"
    return result


def run_suite(source: Path, godot: str, output: Path, timeout: float = 240) -> dict:
    if sys.platform != "linux":
        raise ValueError("This runner supports Linux process-group and XDG isolation only")
    source, output = source.resolve(), output.absolute()
    if not (source / "project.godot").is_file():
        raise ValueError("Missing project.godot")
    if timeout <= 0:
        raise ValueError("Timeout must be positive")
    # Never reuse or remove caller-owned output; resolve symlink parents first.
    if output.exists() or output.is_symlink():
        raise ValueError("Output must be a new directory")
    output = output.resolve()
    temp_parent = Path(tempfile.gettempdir()).resolve()
    if source == output or source in output.parents or source == temp_parent or source in temp_parent.parents:
        raise ValueError("Output and temporary staging must be outside the source project")
    godot = shutil.which(godot) or str(Path(godot).resolve())
    found, manifests = inventory(source)
    output.mkdir(parents=True)
    dump(output / OWNER, {"source": str(source), "kind": "retained logs; never auto-deleted"})
    started = time.monotonic()
    summary = {"inventory": found, "dedicated": [DEDICATED], "manifests": manifests,
               "batches": [], "passed": False, "timeout_seconds": timeout}
    dump(output / "inventory.json", summary)
    with tempfile.TemporaryDirectory(prefix="parallel-godot-") as temporary:
        stage = Path(temporary)
        dump(stage / OWNER, {"source": str(source), "output": str(output)})

        def batch(number: int) -> dict:
            batch_root = stage / f"batch-{number}"
            batch_root.mkdir()
            project = batch_root / "project"
            logs = output / f"batch-{number}"
            logs.mkdir()
            report = {"batch": number, "manifest": manifests[number], "fixtures": []}
            dump(logs / "manifest.json", manifests[number])
            try:
                copy_project(source, project)
                report["import"] = run_engine(godot, project, private_env(batch_root / "import"),
                                              ["--editor", "--quit"], logs / "import.log", timeout)
                for index, script in enumerate(manifests[number]):
                    result = run_engine(godot, project, private_env(batch_root / f"fixture-{index}"),
                                        ["--script", "res://" + script], logs / (Path(script).stem + ".log"), timeout)
                    result["script"] = script
                    report["fixtures"].append(result)
                    dump(logs / "status.json", report)
                    print(f"batch {number}: {script}: {result['status']} ({result['duration_seconds']}s)", flush=True)
            except Exception as exc:
                report["runner_error"] = f"{type(exc).__name__}: {exc}"
            dump(logs / "status.json", report)
            return report

        # Fixed concurrency: no dynamic engine fan-out inside either batch.
        with ThreadPoolExecutor(max_workers=2) as executor:
            futures = [executor.submit(batch, number) for number in range(2)]
            summary["batches"] = [future.result() for future in futures]
    completed = [row["script"] for batch_report in summary["batches"] for row in batch_report["fixtures"]]
    summary["completed_inventory"] = sorted(completed)
    try:
        check_coverage([name for name in found if name != DEDICATED], completed)
        summary["coverage_passed"] = True
    except ValueError as exc:
        summary["coverage_passed"] = False
        summary["coverage_error"] = str(exc)
    summary["passed"] = summary["coverage_passed"] and all(
        "runner_error" not in report and report["import"]["status"] == "passed" and
        all(row["status"] == "passed" for row in report["fixtures"]) for report in summary["batches"])
    summary["duration_seconds"] = round(time.monotonic() - started, 3)
    dump(output / "summary.json", summary)
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path, required=True, help="New log directory outside source; retained on failure")
    args = parser.parse_args()
    try:
        summary = run_suite(args.source, args.godot, args.output)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"Runner setup failed: {exc}\n")
    print(f"Verification logs: {args.output.resolve()}")
    print(f"Completed {len(summary['completed_inventory'])} headless fixtures; "
          f"dedicated actor-depth excluded; {summary['duration_seconds']}s")
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
