"""Guard tests and real Godot transaction checks in disposable price-trial copies.

python tests/test_price_trial_launcher.py --godot /path/to/godot
Use --work-dir NEW_PATH to retain the copies/logs for inspection or CI artifacts.
No test launches the original project or writes to normal user save slots.
Seeded XDG/APPDATA caller guards cover Linux/Windows. macOS uses the read-only
actual-slot snapshot and unique trial directories; macOS device QA is unverified.
"""

import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest import mock

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import launch_price_trial as trial

SOURCE = Path(__file__).resolve().parents[1]
OPTIONS = None


class PriceTrialTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = None
        if OPTIONS.work_dir:
            cls.work = OPTIONS.work_dir.resolve()
            cls.work.mkdir(parents=True, exist_ok=False)
        else:
            cls.temporary = tempfile.TemporaryDirectory(prefix="price-trial-tests-")
            cls.work = Path(cls.temporary.name).resolve()
        cls.source_before = trial.project_files(SOURCE)
        # Read-only snapshot of the actual normal slots, including their absence.
        if sys.platform == "darwin":
            normal_root = Path.home() / "Library/Application Support"
        elif os.name == "nt":
            normal_root = Path(os.environ["APPDATA"])
        else:
            normal_root = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
        normal_dir = normal_root / "Godot/app_userdata/Loop Conquest - 1G Complete Run v03"
        cls.real_slots = {}
        for prefix in ("loop_conquest_profile", "loop_conquest_1d_unlocks"):
            for suffix in ("_a.json", "_b.json"):
                path = normal_dir / (prefix + suffix)
                cls.real_slots[path] = path.read_bytes() if path.exists() else None

    @classmethod
    def tearDownClass(cls):
        if trial.project_files(SOURCE) != cls.source_before:
            raise AssertionError("Original project/game bytes changed")
        for path, before in cls.real_slots.items():
            after = path.read_bytes() if path.exists() else None
            if before != after:
                raise AssertionError("Actual normal profile/unlock slot changed")
        if cls.temporary:
            cls.temporary.cleanup()

    def fixture_source(self, name):
        path = self.work / name
        (path / "game").mkdir(parents=True)
        for name in ("project.godot", "game/run_profile.gd"):
            (path / name).write_bytes((SOURCE / name).read_bytes())
        return path

    def test_malformed_anchors_and_overrides_fail_before_copying(self):
        source = self.fixture_source("malformed source")
        original_config = (source / "project.godot").read_bytes()
        original_profile = (source / "game/run_profile.gd").read_bytes()
        cases = [
            ("game/run_profile.gd", original_profile.replace(trial.GROWTH_ANCHOR, b"const GROWTH_COST := [20, 70]")),
            ("game/run_profile.gd", original_profile + b"\n" + trial.GROWTH_ANCHOR + b"\n"),
            ("project.godot", original_config.replace(trial.SAVE_ANCHOR, b'config/custom_user_dir_name="unknown"')),
            ("project.godot", original_config.replace(b"[application]", b'[application]\nconfig/custom_user_dir_name.windows="old-profile"')),
            ("project.godot", original_config.replace(b"[application]", b'[application]\nconfig/use_custom_user_dir.linux=false')),
            ("project.godot", original_config.replace(b"[application]", b'[application]\nconfig/project_settings_override="user://old.cfg"')),
        ]
        # Later quoted assignments can supersede the canonical anchors in
        # Godot, including escaped names that decode to the same protected key.
        quoted_assignments = [
            b'"config/custom_user_dir_name"="Godot/app_userdata/Loop Conquest - 1G Complete Run v03"',
            b'"config/use_custom_user_dir"=false',
            b'"config/project_settings_override"="user://old.cfg"',
            b'"config/disable_project_settings_override"=false',
            b'"config/custom_user_dir_name.windows"="old-profile"',
            br'"config/custom_user_dir_\u006Eame"="old-profile"',
            br'"config/use_custom_user_di\u0072"=false',
            br'"config/project_settings_\u006Fverride"="user://old.cfg"',
        ]
        for assignment in quoted_assignments:
            cases.append(("project.godot", original_config.replace(
                trial.SAVE_ANCHOR, trial.SAVE_ANCHOR + b"\n" + assignment
            )))
        same_line_assignments = [
            b'"config/custom_user_dir_name"="Godot/app_userdata/Loop Conquest - 1G Complete Run v03"',
            br'"config/custom_user_dir_\u006Eame"="old-profile"',
            b'config/custom_user_dir_name="old-profile"',
            b'config/use_custom_user_dir=false',
            b'config/project_settings_override="user://old.cfg"',
            b'config/disable_project_settings_override=false',
        ]
        for assignment in same_line_assignments:
            cases.append(("project.godot", original_config.replace(
                trial.SAVE_ANCHOR,
                trial.SAVE_ANCHOR + b'\nconfig/name="Trial" ' + assignment,
            )))
        for assignment in (
            b'config/custom_user_dir_name="normal"',
            b'"config/custom_user_dir_name"="normal"',
            b'config/use_custom_user_dir=false',
            b'config/project_settings_override="user://old.cfg"',
        ):
            cases.append(("project.godot", original_config.replace(
                trial.SAVE_ANCHOR, trial.SAVE_ANCHOR + b"\n[application] " + assignment
            )))
        for section_name in (b"application/config", b"application.config", b"", b'"application"'):
            cases.append(("project.godot", original_config.replace(
                trial.SAVE_ANCHOR,
                trial.SAVE_ANCHOR + b"\n[" + section_name + b']\ncustom_user_dir_name="normal"',
            )))
        cases.append(("project.godot", original_config.replace(
            b"config_version=5",
            b'config_version=5\napplication/config/custom_user_dir_name.windows="normal"',
        )))
        # Literal equals signs and semicolons inside values, escaped quotes, and
        # assignments inside comments do not count as additional assignments.
        ordinary_values = original_config.replace(
            b"[application]",
            b'[application]\nconfig/description="literal a=b; c=d" ; "ignored"=true\n'
            br'config/version="escaped \"x=y\""' + b"\n",
        )
        trial.validate_settings(source, ordinary_values)
        for index, (name, data) in enumerate(cases):
            with self.subTest(name=name, case=index):
                (source / "project.godot").write_bytes(original_config)
                (source / "game/run_profile.gd").write_bytes(original_profile)
                (source / name).write_bytes(data)
                destination = self.work / f"invalid-{index}"
                with self.assertRaises(trial.TrialError):
                    trial.prepare(source, destination, "late2")
                self.assertFalse(destination.exists())
        (source / "project.godot").write_bytes(original_config)
        (source / "override.cfg").write_text('[application]\nconfig/custom_user_dir_name="real-saves"\n')
        with self.assertRaises(trial.TrialError):
            trial.prepare(source, self.work / "override-copy", "late2")
        self.assertFalse((self.work / "override-copy").exists())

    def test_unsafe_destinations_never_adopt_or_overwrite(self):
        source = self.fixture_source("destination source")
        occupied = self.work / "unrelated existing"
        occupied.mkdir()
        (occupied / "keep.txt").write_bytes(b"unrelated bytes")
        for destination in (occupied, source, source / "nested", source.parent):
            with self.subTest(destination=str(destination)), self.assertRaises(trial.TrialError):
                trial.prepare(source, destination, "baseline")
        self.assertEqual((occupied / "keep.txt").read_bytes(), b"unrelated bytes")
        self.assertFalse((source / "nested").exists())
        linked = self.work / "linked destination"
        try:
            linked.symlink_to(occupied, target_is_directory=True)
        except OSError:
            return  # Windows without symlink privilege: other guards still run.
        with self.assertRaises(trial.TrialError):
            trial.prepare(source, linked, "baseline")

    def test_resume_binds_curve_content_path_and_profile_receipt(self):
        source = self.fixture_source("resume source")
        destination = self.work / "fixed late2"
        manifest = trial.prepare(source, destination, "late2")
        manifest_data = (destination / trial.MANIFEST).read_bytes()
        with self.assertRaises(trial.TrialError):
            trial.prepare(source, destination, "late2")
        for curve in ("baseline", "late3"):
            with self.assertRaises(trial.TrialError):
                trial.prepare(source, destination, curve, resume=True)
        self.assertEqual(trial.prepare(source, destination, "late2", resume=True), manifest)
        profile = destination / "game/run_profile.gd"
        old_profile = profile.read_bytes()
        profile.write_bytes(old_profile.replace(b"[20, 70]", b"[20, 105]"))
        with self.assertRaises(trial.TrialError):
            trial.verify_copy(destination, "late2")
        profile.write_bytes(old_profile)
        override = destination / "override.cfg"
        override.write_text('[application]\nconfig/custom_user_dir_name="old-profile"\n')
        with self.assertRaises(trial.TrialError):
            trial.verify_copy(destination, "late2")
        override.unlink()
        receipt = trial.user_directory(destination, manifest["custom_user_dir_name"]) / trial.RECEIPT
        receipt.write_bytes(b'{"curve":"late3"}')
        with self.assertRaises(trial.TrialError):
            trial.verify_copy(destination, "late2")
        receipt.write_bytes(manifest_data)
        moved = self.work / "moved copy"
        shutil.copytree(destination, moved)
        with self.assertRaises(trial.TrialError):
            trial.verify_copy(moved, "late2")
        self.assertEqual((destination / trial.MANIFEST).read_bytes(), manifest_data)

    def test_real_engine_prices_transactions_restart_and_save_isolation(self):
        if OPTIONS.unit_only:
            self.skipTest("--unit-only: no real engine checks requested")
        godot = trial.find_godot(OPTIONS.godot)
        # Seed normal slots in an XDG/APPDATA caller root on Linux/Windows;
        # the launcher must isolate every engine invocation from this root.
        # macOS ignores these variables: its normal slots are protected by the
        # read-only actual-slot snapshot above, not by these seeded fixtures.
        caller = self.work / "caller data with existing normal saves"
        caller.mkdir()
        env = trial.runtime_environment(caller)
        normal_name = "Godot/app_userdata/Loop Conquest - 1G Complete Run v03"
        normal = caller / trial.RUNTIME / "data" / normal_name
        normal.mkdir(parents=True)
        guards = {}
        for prefix in ("loop_conquest_profile", "loop_conquest_1d_unlocks"):
            for suffix in ("_a.json", "_b.json"):
                path = normal / (prefix + suffix)
                guards[path] = ("preserve existing " + path.name).encode()
                path.write_bytes(guards[path])
        report = []
        identities = set()
        with mock.patch.dict(os.environ, env):
            for curve, costs in trial.CURVES.items():
                destination = self.work / (curve + " engine copy with spaces")
                manifest = trial.prepare(SOURCE, destination, curve)
                identities.add(manifest["custom_user_dir_name"])
                save_dir = trial.user_directory(destination, manifest["custom_user_dir_name"])
                self.assertEqual({p.name for p in save_dir.iterdir()}, {trial.RECEIPT})
                version = trial.import_copy(godot, destination, curve)
                # Actual unchanged main scene startup before synthetic test setup.
                startup = trial.checked_engine(godot, destination, ["--headless", "--path", str(destination), "--quit-after", "3"])
                (destination / "startup.log").write_text(startup, encoding="utf-8")
                for phase in ("purchase", "reset", "reload"):
                    # disable_project_settings_override also disables --script.
                    # Inject only a test autoload, retaining the real main scene
                    # and override protection; restore before integrity/resume.
                    config_path = destination / "project.godot"
                    config_bytes = config_path.read_bytes()
                    probe = destination / "price_trial_probe.gd"
                    probe.write_bytes((SOURCE / "tests/price_trial_probe.gd").read_bytes())
                    try:
                        config_path.write_bytes(config_bytes + b'\n[autoload]\nPriceTrialProbe="*res://price_trial_probe.gd"\n')
                        output = trial.checked_engine(godot, destination, [
                            "--headless", "--path", str(destination),
                            "--", "--synthetic-price-check", str(costs[1]), str(save_dir), phase,
                        ], timeout=30)
                    finally:
                        config_path.write_bytes(config_bytes)
                        probe.unlink()
                    (destination / (phase + ".log")).write_text(output, encoding="utf-8")
                    lines = [line.removeprefix("PRICE_TRIAL_CHECK ") for line in output.splitlines() if line.startswith("PRICE_TRIAL_CHECK ")]
                    self.assertEqual(len(lines), 1, output)
                    result = json.loads(lines[0])
                    self.assertTrue(result["passed"], output)
                    report.append(dict(curve=curve, engine=version, **result))
                    self.assertEqual(trial.prepare(SOURCE, destination, curve, resume=True), manifest)
                self.assertEqual(trial.project_files(SOURCE), self.source_before)
                for path, data in guards.items():
                    self.assertEqual(path.read_bytes(), data)
                self.assertEqual(set(normal.iterdir()), set(guards))
        self.assertEqual(len(identities), 3)
        (self.work / "engine-summary.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print("Real engine: all three curves passed fresh startup, UI prices, purchase, reset, restart and actual normal-slot byte/absence guards; seeded caller guards apply to Linux/Windows", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("PRICE_TRIAL_GODOT"))
    parser.add_argument("--work-dir", type=Path)
    parser.add_argument("--unit-only", action="store_true")
    OPTIONS, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining], verbosity=2)
