"""Prepare or execute one bounded, owned-process native stack run.

Default is dry-run: no process discovery, sampler attachment or engine launch.
Execution requires BOTH --execute and --slot-authorized, supplied only after the
parent explicitly assigns an exclusive engine slot. No sudo, installation,
security changes, cross-process capture or automatic sampler fallback.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import queue
import re
import subprocess
import threading
import time


def sampler_command(tool, pid, output):
    if tool == "sample":
        return ["/usr/bin/sample", str(pid), "8", "2", "-mayDie", "-file", str(output)]
    if tool == "spindump":
        return ["/usr/sbin/spindump", str(pid), "8", "2", "-onlyTarget", "-timeline", "-timelimit", "15", "-o", str(output)]
    raise ValueError("Unknown sampler")


def stop_owned(proc):
    if proc is not None and proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=3)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--tool", choices=["sample", "spindump"], default="sample")
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--slot-authorized", action="store_true")
    args = parser.parse_args()
    engine, project, output_dir = args.engine.resolve(), args.project.resolve(), args.output_dir.resolve()
    project_text = (project / "project.godot").read_text()
    if not re.search(r'^config/custom_user_dir_name="CodexV49Lag-[0-9a-f-]+"$', project_text, re.M):
        parser.error("Project must use an isolated CodexV49Lag UUID user directory")
    fixture = project / "tests/profile_v49_hitch.gd"
    if 'STACK_WINDOW_START' not in fixture.read_text():
        parser.error("Prepare a new QA copy with the 12-second stack marker first")
    executable = Path(sampler_command(args.tool, 0, Path("unused"))[0])
    if not engine.is_file() or not executable.is_file():
        parser.error("Required existing engine or system sampler is missing; nothing installed")
    run_command = [str(engine), "--path", str(project), "--rendering-driver", "opengl3", "--script", "res://tests/profile_v49_hitch.gd", "--", "--walk", "--combat", "--region=temple", "--output=" + str(output_dir / "native.json")]
    plan = {"dry_run": not args.execute, "engine": run_command,
            "sampler": sampler_command(args.tool, "<PID returned by this runner's Popen>", output_dir / "stack.txt"),
            "start": "one stdout marker at active game time>=12s; duration8 wall seconds, interval2ms",
            "sampler_scope": "exact owned engine PID only", "watchdog_seconds": 35,
            "limits": "Sampling perturbs execution; sample is aggregated, spindump timeline attachment privilege unverified; no GPU or FPS proof"}
    print(json.dumps(plan, indent=2), flush=True)
    if not args.execute:
        return
    if not args.slot_authorized:
        parser.error("No execution without an explicit parent engine-slot assignment")
    if output_dir.exists():
        parser.error("Execution output directory must be new; preserve previous evidence")
    # Read-only preflight, only in explicitly authorized execution mode.
    check = subprocess.run(["/bin/ps", "-Ao", "pid=,comm="], capture_output=True, text=True, timeout=3)
    if check.returncode:
        raise RuntimeError("Process inspection denied; stop without privilege workarounds")
    if any(re.search(r"(?:/Godot$|Loop.?Conquest)", line) for line in check.stdout.splitlines()):
        raise RuntimeError("Existing engine/game process found; stop without launching or touching it")
    output_dir.mkdir(parents=True)
    records = queue.Queue()
    native = sampler = None
    start = time.monotonic()
    metadata = {"plan": plan, "engine_sha256": hashlib.sha256(engine.read_bytes()).hexdigest(),
                "start_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "marker": None,
                "sample_launched_monotonic": None, "sampler_exit": None, "failure": None}
    sample_stream = None
    try:
        native = subprocess.Popen(run_command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        metadata["owned_native_pid"] = native.pid

        def consume():
            with (output_dir / "native.log").open("w") as log:
                for line in native.stdout:
                    log.write(line)
                    if line.startswith("STACK_WINDOW_START "):
                        records.put((time.monotonic(), line[len("STACK_WINDOW_START "):]))
        reader = threading.Thread(target=consume, daemon=True)
        reader.start()
        while native.poll() is None and time.monotonic() - start < 35:
            try:
                marker_time, marker_text = records.get(timeout=0.1)
            except queue.Empty:
                continue
            if sampler is not None:
                continue
            marker = json.loads(marker_text)
            if marker["pid"] != native.pid or marker["region"] != "temple" or not 12 <= marker["run_time"] < 13:
                raise RuntimeError("Unexpected source/PID/time marker; no sampler attached")
            metadata["marker"] = marker
            metadata["marker_seen_elapsed_seconds"] = marker_time - start
            sample_stream = (output_dir / "sampler.log").open("w")
            metadata["sample_launched_monotonic"] = time.monotonic()
            sampler = subprocess.Popen(sampler_command(args.tool, native.pid, output_dir / "stack.txt"), stdout=sample_stream, stderr=subprocess.STDOUT)
            metadata["owned_sampler_pid"] = sampler.pid
        if native.poll() is None:
            metadata["failure"] = "Owned native watchdog exceeded35s"
            stop_owned(native)
        metadata["native_exit"] = native.returncode
        if native.returncode:
            metadata["failure"] = "Native exited with a nonzero status; data are not a clean full PASS"
        reader.join(timeout=2)
        if sampler is not None:
            try:
                sampler.wait(timeout=max(0.1, 35 - (time.monotonic() - start)))
            except subprocess.TimeoutExpired:
                metadata["failure"] = "Owned sampler watchdog expired"
                stop_owned(sampler)
            metadata["sampler_exit"] = sampler.returncode
            if sampler.returncode:
                metadata["failure"] = "Sampler failed; preserve error and stop, no sudo/security changes/automatic fallback"
        else:
            metadata["failure"] = "No valid12s marker; no stack captured"
    except Exception as exc:
        metadata["failure"] = str(exc)
        raise
    finally:
        stop_owned(sampler)
        stop_owned(native)
        if sample_stream is not None:
            sample_stream.close()
        metadata["elapsed_seconds"] = time.monotonic() - start
        (output_dir / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(json.dumps(metadata, indent=2), flush=True)


if __name__ == "__main__":
    main()
