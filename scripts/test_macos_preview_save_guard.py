"""Pure path guard tests; no engine, network or actual Mac user data."""
from pathlib import Path
import tempfile
import unittest
from macos_preview_build import preview_data_directory

class PreviewSaveGuard(unittest.TestCase):
    def test_clean_home_keeps_v45_family_without_creating_it(self):
        with tempfile.TemporaryDirectory() as root:
            path = preview_data_directory(root)
            self.assertEqual(path, Path(root) / "Library/Application Support/LoopConquest-FieldPreview-v45")
            self.assertFalse(path.exists())

    def test_existing_record_directory_is_preserved(self):
        with tempfile.TemporaryDirectory() as root:
            path = preview_data_directory(root)
            path.mkdir(parents=True)
            record = path / "first_region_shared_v45_profile_a.json"
            record.write_bytes(b"existing-player-bytes")
            with self.assertRaisesRegex(RuntimeError, "Refusing"):
                preview_data_directory(root)
            self.assertEqual(record.read_bytes(), b"existing-player-bytes")

    def test_existing_file_also_blocks_fixture_startup(self):
        with tempfile.TemporaryDirectory() as root:
            path = preview_data_directory(root)
            path.parent.mkdir(parents=True)
            path.write_bytes(b"not-a-directory")
            with self.assertRaises(RuntimeError):
                preview_data_directory(root)
            self.assertEqual(path.read_bytes(), b"not-a-directory")

if __name__ == "__main__":
    unittest.main()
