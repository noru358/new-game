#!/usr/bin/env python3
"""Fast fake-engine checks; these do not substitute for real Godot/CI coverage."""
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("parallel_runner", Path(__file__).resolve().parents[1] / "scripts/run_parallel_verifications.py")
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)

FAKE = r'''#!/usr/bin/env python3
import fcntl, json, os, pathlib, subprocess, sys, time
keys = ("HOME", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "XDG_RUNTIME_DIR", "XDG_DATA_DIRS", "XDG_CONFIG_DIRS")
env = {key: os.environ[key] for key in keys}
assert all(pathlib.Path(value).is_absolute() for value in env.values())
assert not any(word in key for key in os.environ for word in ("CAPTURE", "REPORT", "OUTPUT"))
root = pathlib.Path(sys.argv[sys.argv.index("--path") + 1])
# Kernel releases the per-project lock even after a timeout/SIGKILL.
lock = (root / "engine.lock").open("w")
fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
assert (root / "game/asset.import").read_bytes() == b"authored import settings\x00"
assert not (root / ".git").exists()
assert not (root / "docs/measurements").exists()
assert not (root / "verification-logs").exists()
if "--editor" in sys.argv:
    assert not (root / ".godot").exists()
    (root / ".godot").mkdir()
    (root / ".godot/imported").write_text("private cache")
    print(json.dumps({"import_env": env, "project": str(root)}), flush=True)
    sys.exit(0)
assert (root / ".godot/imported").read_text() == "private cache"
script = sys.argv[sys.argv.index("--script") + 1].removeprefix("res://")
mode = (root / script).read_text()
saved = pathlib.Path(env["XDG_DATA_HOME"]) / "save"
assert not saved.exists()
saved.write_text(script)
(root / "sentinel").write_text("only the copy changed")
print(json.dumps({"env": env, "project": str(root), "script": script, "sentinel_inode": (root / "sentinel").stat().st_ino}), flush=True)
child = subprocess.run([sys.executable, "-c", "import os,json; print(json.dumps(dict(os.environ)))"], capture_output=True, text=True, check=True)
child_env = json.loads(child.stdout)
assert all(child_env[key] == value for key, value in env.items())
print("CHILD_INHERITED", flush=True)
if mode == "timeout":
    descendant = subprocess.Popen([sys.executable, "-c", "import time,pathlib; time.sleep(1); pathlib.Path('descendant-survived').write_text('bad'); time.sleep(30)"])
    print("DESCENDANT_PID=" + str(descendant.pid), flush=True)
    time.sleep(30)
if mode == "nonzero": sys.exit(7)
if mode == "error": print("SCRIPT ERROR: deliberately injected")
if mode == "parse": print("Parse Error: deliberately injected")
if mode == "fail": print("FAIL: deliberately injected")
if mode == "pass": time.sleep(0.03)
print("COMPLETE", flush=True)
'''


class ParallelVerificationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="parallel-runner-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root / "source"
        self.source.mkdir()
        (self.source / "project.godot").write_text("fake project")
        (self.source / "sentinel").write_bytes(b"caller source sentinel\x00")
        (self.source / "tests").mkdir()
        (self.source / "game").mkdir()
        (self.source / "game/asset.import").write_bytes(b"authored import settings\x00")
        for relative in (".git/config", ".godot/cache", "docs/measurements/generated", "verification-logs/old.log"):
            path = self.source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"caller generated sentinel")
        self.fixture("actor_terrain_depth", "never run")
        self.engine = self.root / "fake_engine"
        self.engine.write_text(FAKE)
        self.engine.chmod(0o755)
        self.caller = self.root / "caller-data"
        self.caller.mkdir()
        (self.caller / "sentinel").write_bytes(b"caller user data\x00")
        self.environment = patch.dict(os.environ, {key: str(self.caller) for key in runner.USER_DIRS} |
                                      {"FOCUS_CAPTURE_DIR": str(self.caller), "OTHER_REPORT_PATH": str(self.caller), "ACTOR_DEPTH_OUTPUT": str(self.caller)})
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def fixture(self, name, mode):
        (self.source / "tests" / f"verify_{name}.gd").write_text(mode)

    def snapshot(self):
        return {str(path.relative_to(self.source)): path.read_bytes() for path in self.source.rglob("*") if path.is_file()}

    def run_suite(self, timeout=3):
        before = self.snapshot()
        summary = runner.run_suite(self.source, str(self.engine), self.root / "logs", timeout)
        self.assertEqual(before, self.snapshot())
        self.assertEqual((self.caller / "sentinel").read_bytes(), b"caller user data\x00")
        self.assertEqual(list(self.caller.iterdir()), [self.caller / "sentinel"])
        self.assertEqual(summary, json.loads((self.root / "logs/summary.json").read_text()))
        return summary

    def records(self, summary):
        for batch in summary["batches"]:
            for row in batch["fixtures"]:
                log = self.root / "logs" / f"batch-{batch['batch']}" / row["log"]
                yield row, log.read_text()

    def test_disjoint_fixtures_child_inheritance_private_copies_and_exact_inventory(self):
        for name in ("a", "b", "c", "d", "e"):
            self.fixture(name, "pass")
        summary = self.run_suite()
        self.assertTrue(summary["passed"], summary)
        self.assertEqual(len(summary["batches"]), 2)
        self.assertFalse(set(summary["manifests"][0]) & set(summary["manifests"][1]))
        self.assertEqual(summary["dedicated"], [runner.DEDICATED])
        expected = sorted(f"tests/verify_{name}.gd" for name in "abcde")
        self.assertEqual(summary["completed_inventory"], expected)
        fixtures, projects = [], set()
        for row, log in self.records(summary):
            record = json.loads(log.splitlines()[0])
            self.assertIn("CHILD_INHERITED", log)
            fixtures.extend(record["env"].values())
            projects.add(record["project"])
            self.assertNotEqual(record["sentinel_inode"], (self.source / "sentinel").stat().st_ino)
        self.assertEqual(len(fixtures), len(set(fixtures)))
        self.assertEqual(len(projects), 2)
        self.assertTrue(all(not Path(path).exists() for path in projects))
        for batch in summary["batches"]:
            imported = json.loads((self.root / "logs" / f"batch-{batch['batch']}" / "import.log").read_text())
            self.assertFalse(set(imported["import_env"].values()) & set(fixtures))

    def test_failures_continue_join_and_timeout_kills_descendant(self):
        for name, mode in (("a", "timeout"), ("b", "pass"), ("c", "nonzero"),
                           ("d", "error"), ("e", "parse"), ("f", "fail"), ("g", "pass"), ("h", "pass")):
            self.fixture(name, mode)
        summary = self.run_suite(timeout=0.6)
        self.assertFalse(summary["passed"])
        self.assertTrue(summary["coverage_passed"])
        records = {row["script"]: (row, log) for row, log in self.records(summary)}
        self.assertEqual(len(records), 8)
        self.assertTrue(records["tests/verify_a.gd"][0]["timeout"])
        self.assertEqual(records["tests/verify_c.gd"][0]["exit_code"], 7)
        for name in "def":
            row = records[f"tests/verify_{name}.gd"][0]
            self.assertEqual(row["exit_code"], 0)
            self.assertTrue(row["error_text"])
        for name in "bgh":
            self.assertEqual(records[f"tests/verify_{name}.gd"][0]["status"], "passed")
        log = records["tests/verify_a.gd"][1]
        pid = int(next(line.split("=")[1] for line in log.splitlines() if line.startswith("DESCENDANT_PID=")))
        time.sleep(0.1)
        proc = Path(f"/proc/{pid}/stat")
        # An orphan zombie is already dead and may await PID 1 reaping in containers.
        self.assertTrue(not proc.exists() or proc.read_text().split()[2] == "Z")

    def test_import_failure_is_still_fatal_and_fixtures_continue(self):
        for name in "ab": self.fixture(name, "pass")
        self.engine.write_text(FAKE.replace('sys.exit(0)', 'print("Parse Error: import failed"); sys.exit(0)'))
        summary = self.run_suite()
        self.assertFalse(summary["passed"])
        self.assertTrue(summary["coverage_passed"])
        self.assertTrue(all(report["import"]["error_text"] for report in summary["batches"]))
        self.assertTrue(all(row["status"] == "passed" for row, _ in self.records(summary)))

    def test_coverage_rejects_missing_duplicate_and_unexpected(self):
        for actual in (["a"], ["a", "b", "b"], ["a", "z"]):
            with self.assertRaises(ValueError):
                runner.check_coverage(["a", "b"], actual)

    def test_caller_owned_output_and_nested_source_output_rejected(self):
        for name in "ab": self.fixture(name, "pass")
        for output in (self.caller, self.source / "new-output"):
            with self.assertRaises(ValueError):
                runner.run_suite(self.source, str(self.engine), output)
        self.assertFalse((self.source / "new-output").exists())

    def test_symlink_source_fails_coverage_without_mutating_target(self):
        for name in "ab": self.fixture(name, "pass")
        (self.source / "external").symlink_to(self.caller, target_is_directory=True)
        summary = self.run_suite()
        self.assertFalse(summary["passed"])
        self.assertFalse(summary["coverage_passed"])
        self.assertTrue(all("runner_error" in report for report in summary["batches"]))


if __name__ == "__main__":
    unittest.main()
