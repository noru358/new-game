"""Pure preview guards; no real user directory, network, or Godot required."""
from pathlib import Path
import json
import tempfile
import unittest
from windows_preview_contract import preview_config, SAVE_FAMILY, PROFILE_PREFIX, snapshot, shared_bytes, seed_wetland_access

CONFIG = 'config/name="Original"\nconfig/custom_user_dir_name="Godot/app_userdata/Loop Conquest - 1G Complete Run v03"\nrun/main_scene="res://game/travel_camp.tscn"\n'
COMMIT = 'fixture-commit'

class Contract(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / '.windows-preview-owner').write_text(COMMIT)
        self.data = self.root / SAVE_FAMILY
        self.data.mkdir()
        self.slot = self.data / f'{PROFILE_PREFIX}_a.json'
        self.record = {'version':7,'generation':3,'currency':21,'last_launch_id':'launch-a','last_run_id':'settled-a','owned_outpost_ids':[], 'acquired_relic_ids':[], 'future_optional_field':'preserve'}
        self.slot.write_text(json.dumps(self.record))
    def tearDown(self): self.temp.cleanup()
    def test_exact_packaging_overrides(self):
        value=preview_config(CONFIG,'v46')
        self.assertIn('field_preview_entry.tscn',value)
        self.assertIn(SAVE_FAMILY,value)
        self.assertIn('v46 Field Preview',value)
        self.assertIn('Original',CONFIG)
    def test_bad_or_duplicate_anchors(self):
        for value in [CONFIG.replace('travel_camp','missing'),CONFIG+CONFIG]:
            with self.assertRaises(RuntimeError):preview_config(value,'v46')
        with self.assertRaises(RuntimeError):preview_config(CONFIG,'../../unsafe')
    def test_seed_only_owned_progression_fields(self):
        before=snapshot(self.root,COMMIT)
        result=seed_wetland_access(self.root,COMMIT)
        after=snapshot(self.root,COMMIT)
        self.assertTrue(result['runner_only'])
        self.assertFalse(result['natural_campaign_win'])
        for key in ['currency','generation','last_launch_id','last_run_id']:self.assertEqual(before[key],after[key])
        self.assertEqual(after['owned_outpost_ids'],['O_TEMPLE','O_JUNGLE_PASS'])
        self.assertEqual(json.loads(self.slot.read_text())['future_optional_field'],'preserve')
        seed_wetland_access(self.root,COMMIT)
        self.assertEqual(snapshot(self.root,COMMIT),after)
    def test_marker_required(self):
        before=self.slot.read_bytes()
        with self.assertRaises(RuntimeError):seed_wetland_access(self.root,'different')
        self.assertEqual(self.slot.read_bytes(),before)
    def test_future_format_preserved(self):
        self.record['version']=8;self.slot.write_text(json.dumps(self.record));before=self.slot.read_bytes()
        with self.assertRaises(RuntimeError):seed_wetland_access(self.root,COMMIT)
        self.assertEqual(self.slot.read_bytes(),before)
    def test_invalid_generation_refused(self):
        for value in [-1,0,1.5,float('nan'),True]:
            self.record['generation']=value;self.slot.write_text(json.dumps(self.record))
            with self.assertRaises(RuntimeError):snapshot(self.root,COMMIT)
    def test_unknown_slot_refused(self):
        (self.data/f'{PROFILE_PREFIX}_c.json').write_text('{}')
        with self.assertRaises(RuntimeError):seed_wetland_access(self.root,COMMIT)
    def test_shared_record_snapshot(self):
        before=shared_bytes(self.root,COMMIT)
        self.assertEqual(before[self.slot.name],self.slot.read_bytes())
        self.assertEqual(snapshot(self.root,COMMIT)['last_launch_id'],'launch-a')
    def test_symlink_slot_refused(self):
        target=self.root/'outside-fixture.json';target.write_text(json.dumps(self.record));self.slot.unlink()
        try:self.slot.symlink_to(target)
        except OSError:self.skipTest('OS does not permit test symlinks')
        with self.assertRaises(RuntimeError):seed_wetland_access(self.root,COMMIT)
        with self.assertRaises(RuntimeError):shared_bytes(self.root,COMMIT)

class ReleaseContentGuard(unittest.TestCase):
    def test_development_roots_and_remapped_textures_are_rejected(self):
        from windows_export_smoke import verify_release_contents
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name in ('docs', 'tests', 'scripts', 'patches', 'integration', 'evidence'):
                directory = root / name
                directory.mkdir()
                imported = 'res://.godot/imported/' + name + '-fixture.ctex'
                (directory / 'fixture.png.import').write_text('[remap]\npath="' + imported + '"\n')
                for path in ('res://' + name + '/fixture.png.remap', imported):
                    with self.subTest(root=name, path=path):
                        with self.assertRaises(RuntimeError):
                            verify_release_contents(root, 'Storing File: res://game/player.gdc\nStoring File: ' + path)
            result = verify_release_contents(root, 'Storing File: res://game/player.gdc')
            self.assertEqual(result['development_resources_packed'], 0)
            self.assertEqual(result['development_imports_checked'], 6)

    def test_all_presets_exclude_development_roots(self):
        import re
        text = (Path(__file__).resolve().parents[1] / 'export_presets.cfg').read_text()
        exclusions = re.findall(r'^exclude_filter="([^"]*)"', text, re.M)
        self.assertTrue(exclusions)
        for value in exclusions:
            for name in ('docs', 'tests', 'scripts', 'patches', 'integration', 'evidence'):
                self.assertIn(name + '/*', value.split(','))

if __name__=='__main__':unittest.main()
