"""Pure helpers for runner-owned Windows field-preview startup fixtures."""
import json
import math
from pathlib import Path
import re

SAVE_FAMILY = "LoopConquest-FieldPreview-v45"
PROFILE_PREFIX = "first_region_shared_v45_profile"
SCENES = [
    ("camp", "res://game/travel_camp.tscn", None),
    ("temple-circuit", "res://game/temple_circuit_run.tscn", "Hybrid scene ready: Temple circuit — isolated four-minute run"),
    ("jungle-south", "res://game/jungle_south_circuit.tscn", "Hybrid scene ready: Jungle southern circuit — isolated development run"),
    ("deep-wetland", "res://game/deep_wetland_trial.tscn", "Hybrid scene ready: Deep Temple Wetland — representative route"),
    ("wetland-run", "res://game/deep_wetland_run.tscn", "Hybrid scene ready: Loop Conquest — 깊은 사원 습지"),
]


def preview_config(text, label):
    if not re.fullmatch(r"v[0-9]+(?:\.[0-9]+)?", label):
        raise RuntimeError("Invalid field-preview label")
    replacements = {
        'config/custom_user_dir_name="Godot/app_userdata/Loop Conquest - 1G Complete Run v03"': f'config/custom_user_dir_name="{SAVE_FAMILY}"',
        'run/main_scene="res://game/travel_camp.tscn"': 'run/main_scene="res://game/field_preview_entry.tscn"',
    }
    for old, new in replacements.items():
        if text.count(old) != 1:
            raise RuntimeError("Unexpected original project contract")
        text = text.replace(old, new)
    if len(re.findall(r'^config/name="[^"]+"$', text, re.M)) != 1:
        raise RuntimeError("Unexpected project title contract")
    return re.sub(r'^config/name="[^"]+"$', f'config/name="Loop Conquest - {label} Field Preview"', text, count=1, flags=re.M)


def owned_directory(runtime_data, commit):
    root = Path(runtime_data)
    marker = root / ".windows-preview-owner"
    if root.is_symlink() or marker.is_symlink() or not marker.is_file() or marker.read_text() != commit:
        raise RuntimeError("Missing runner-owned preview marker")
    path = root / SAVE_FAMILY
    if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
        raise RuntimeError("Preview path escapes isolated runtime APPDATA")
    return path


def slots(runtime_data, commit):
    directory = owned_directory(runtime_data, commit)
    expected = {directory / f"{PROFILE_PREFIX}_{suffix}.json" for suffix in ("a", "b")}
    found = set(directory.glob(f"{PROFILE_PREFIX}_*.json"))
    if found - expected:
        raise RuntimeError("Unexpected preview profile slot")
    result = []
    for path in sorted(found):
        if path.is_symlink() or not path.resolve().is_relative_to(Path(runtime_data).resolve()):
            raise RuntimeError("Profile slot escapes runner-owned directory")
        data = json.loads(path.read_text())
        if data.get("version") != 7 or isinstance(data.get("generation"), bool) or not isinstance(data.get("generation"), (int, float)) or not math.isfinite(data["generation"]) or data["generation"] < 1 or int(data["generation"]) != data["generation"]:
            raise RuntimeError("Unsupported startup fixture schema")
        if not isinstance(data.get("owned_outpost_ids"), list) or not isinstance(data.get("acquired_relic_ids"), list):
            raise RuntimeError("Unexpected ownership fixture shape")
        result.append((path, data))
    return result


def snapshot(runtime_data, commit):
    records = slots(runtime_data, commit)
    if not records:
        return None
    data = max(records, key=lambda item: item[1]["generation"])[1]
    return {key: data.get(key) for key in ["generation", "currency", "last_launch_id", "last_run_id", "owned_outpost_ids", "acquired_relic_ids"]}


def shared_bytes(runtime_data, commit):
    directory = owned_directory(runtime_data, commit)
    result = {}
    for path in directory.glob("first_region_shared_v45_*.json"):
        if path.is_symlink() or not path.resolve().is_relative_to(Path(runtime_data).resolve()):
            raise RuntimeError("Shared record escapes runner-owned directory")
        if path.is_file(): result[path.name] = path.read_bytes()
    return result


def seed_wetland_access(runtime_data, commit):
    records = slots(runtime_data, commit)
    if not records:
        raise RuntimeError("No earlier runner-owned shared profile to seed")
    for path, data in records:
        for region in ["O_TEMPLE", "O_JUNGLE_PASS"]:
            if region not in data["owned_outpost_ids"]:
                data["owned_outpost_ids"].append(region)
        if "RELIC_TEMPLE" not in data["acquired_relic_ids"]:
            data["acquired_relic_ids"].append("RELIC_TEMPLE")
        path.write_text(json.dumps(data))
    return {"runner_only": True, "preseeded_temple_and_jungle_access": True, "natural_campaign_win": False}
