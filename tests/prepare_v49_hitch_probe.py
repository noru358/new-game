"""Prepare an isolated QA copy with timing wrappers; never launch Godot.

Usage: python3 tests/prepare_v49_hitch_probe.py --source <source> --output <new-dir>
Use only after the parent assigns an engine slot to run the prepared copy.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import uuid

METHODS = {
    "game/hybrid_height.gd": ["_process", "_physics_process", "_on_wisp_hit", "_on_player_attack_landed", "_flash", "_sphere", "_update_health_bar", "_draw_attack_at"],
    "game/hybrid_region.gd": ["_process", "_physics_process", "_choose_spawn_point", "_schedule_spawn", "_spawn_now"],
    "game/player.gd": ["_physics_process", "_play_sound"],
    "game/enemy.gd": ["_physics_process"],
    "game/temple_section.gd": ["tick", "_set_field"],
    "game/arena_navigation.gd": ["find_path"],
    "game/run_flow_hud_presenter.gd": ["refresh"],
    "game/enemy_role_visual.gd": ["_texture"],
}
DETAILS = {
    "_on_wisp_hit": 'str(enemy.global_position)',
    "_on_player_attack_landed": '[str(point), step, finisher]',
    "_flash": '[str(point), radius]',
    "_sphere": '[radius, str(color)]',
    "_play_sound": 'path',
    "_schedule_spawn": '[str(point), role, for_boss]',
    "_spawn_now": '[str(point), role, for_boss]',
    "_texture": '[role, hit]',
    "_set_field": 'value',
}


def split_args(value):
    """Split declarations only at commas outside parentheses/brackets/strings."""
    parts, start, depth, quote = [], 0, 0, None
    for i, ch in enumerate(value):
        if quote:
            if ch == quote and (i == 0 or value[i - 1] != "\\"):
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            parts.append(value[start:i].strip())
            start = i + 1
    if value[start:].strip():
        parts.append(value[start:].strip())
    return parts


def wrap(source, file, method):
    pattern = re.compile(r"^(static )?func " + re.escape(method) + r"\((.*)\)([^\n]*):[ \t]*$", re.M)
    matches = list(pattern.finditer(source))
    if len(matches) != 1:
        raise ValueError(f"Expected one {file}:{method}, found {len(matches)}")
    m = matches[0]
    args = ", ".join(re.match(r"\w+", part).group() for part in split_args(m[2]))
    static = m[1] or ""
    # Names must differ between base/derived scripts to avoid virtual recursion.
    renamed = "_v49_trace_" + Path(file).stem + method
    result_void = "-> void" in m[3]
    label = f"{file}:{method}"
    call = f"{renamed}({args})"
    detail = DETAILS.get(method, "null")
    wrapper = (f"{m[0]}\n\tvar v49_started := V49HitchTrace.begin()\n"
               + (f"\t{call}\n" if result_void else f"\tvar v49_result = {call}\n")
               + f'\tV49HitchTrace.finish("{label}", v49_started, {detail})\n'
               + ("" if result_void else "\treturn v49_result\n"))
    replacement = f"{static}func {renamed}({m[2]}){m[3]}:"
    return source[:m.start()] + wrapper + "\n" + replacement + source[m.end():]


def prepare(source, target):
    source, target = source.resolve(), target.resolve()
    if target.exists() or source == target or source in target.parents:
        raise ValueError("Output must be a new directory outside the source checkout")
    if not (source / "project.godot").is_file():
        raise ValueError("Source must be a Godot project")
    shutil.copytree(source, target, ignore=shutil.ignore_patterns(".git", ".godot", "evidence", "docs", "integration"))
    fixture = Path(__file__).parent / "fixtures/v49_hitch_trace.gd"
    (target / "tests/fixtures").mkdir(parents=True, exist_ok=True)
    shutil.copy2(fixture, target / "tests/fixtures/v49_hitch_trace.gd")
    manifest = {"source": str(source), "qa_only": True, "engine_launched": False, "files": {}}
    for file, methods in METHODS.items():
        original = (source / file).read_text()
        modified = original
        for method in methods:
            modified = wrap(modified, file, method)
        lines = modified.splitlines(keepends=True)
        line = next(i for i, text in enumerate(lines) if text.startswith("extends "))
        # hybrid_region inherits this constant from the instrumented hybrid_height.
        if file != "game/hybrid_region.gd":
            lines.insert(line + 1, 'const V49HitchTrace = preload("res://tests/fixtures/v49_hitch_trace.gd")\n')
        (target / file).write_text("".join(lines))
        manifest["files"][file] = {"source_sha256": hashlib.sha256(original.encode()).hexdigest(), "methods": methods}
    project = (target / "project.godot").read_text()
    user_dir = "CodexV49Lag-" + str(uuid.uuid4())
    project, count = re.subn(r'^config/custom_user_dir_name=.*$', f'config/custom_user_dir_name="{user_dir}"', project, flags=re.M)
    if count != 1:
        raise ValueError("Expected explicit custom user directory setting")
    (target / "project.godot").write_text(project)
    manifest["user_directory"] = user_dir
    profiler = (source / "tests/profile_spawn_lag.gd").read_text()
    profiler = profiler.replace("extends SceneTree\n", 'extends SceneTree\nconst Trace = preload("res://tests/fixtures/v49_hitch_trace.gd")\n')
    profiler = profiler.replace('var focus_resumes:=0', 'var focus_resumes:=0\nvar stack_window_announced:=false')
    profiler = profiler.replace("func _initialize():\n", "func _initialize():\n\tTrace.reset()\n")
    profiler = profiler.replace('\n\troot.add_child(arena)', '\n\tif arena.get_script() == null:\n\t\tprinterr("QA scene script failed to load")\n\t\tquit(2)\n\t\treturn\n\troot.add_child(arena)')
    profiler = profiler.replace("RenderingServer.frame_post_draw.connect(sample_frame)", "RenderingServer.frame_post_draw.connect(sample_frame)\n\tRenderingServer.frame_pre_draw.connect(sample_pre_draw)")
    profiler = profiler.replace("create_timer(60.0)", "create_timer(19.0)")
    profiler = profiler.replace('FileAccess.open(output,FileAccess.WRITE)', 'report["timeline"] = Trace.report()\n\tFileAccess.open(output,FileAccess.WRITE)')
    profiler = profiler.replace("func sample_frame():\n", "func sample_frame():\n\tTrace.mark(\"render_post_draw\", {\"run_time\":arena.run_time, \"position\":str(arena.player.position), \"camera\":str(arena.camera.position), \"route_index\":route_index, \"waypoint\":waypoint, \"xp\":arena.growth.xp, \"level\":arena.growth.level, \"attack_step\":arena.player.attack_step, \"pending_spawns\":arena.pending_spawns.size(), \"enemies\":arena._active_enemy_count()})\n")
    profiler = profiler.replace('func sample_frame():\n', 'func sample_frame():\n\tif not stack_window_announced and arena.run_time >= 12.0:\n\t\tstack_window_announced = true\n\t\tprint("STACK_WINDOW_START ", JSON.stringify({"pid":OS.get_process_id(), "run_time":arena.run_time, "ticks_usec":Time.get_ticks_usec(), "origin_usec":Trace.origin_usec, "region":region}))\n')
    profiler = profiler.replace("func steer():\n", "func steer():\n\tTrace.mark(\"physics_frame\")\n")
    # Add absolute clocks and engine frame IDs alongside the existing sample columns.
    profiler = profiler.replace('frames.append([float(now-last_usec)/1000.0,', 'Trace.mark("frame_sample", [now, Engine.get_frames_drawn(), Engine.get_process_frames(), Engine.get_physics_frames(), float(now-last_usec)/1000.0, Performance.get_monitor(Performance.TIME_PROCESS)*1000.0])\n\t\tframes.append([float(now-last_usec)/1000.0,')
    profiler = profiler.replace('\n\troot.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")', '')
    profiler = profiler.replace('\n\tquit()\nfunc sample_frame():', '\n\tRenderingServer.frame_pre_draw.disconnect(sample_pre_draw)\n\tRenderingServer.frame_post_draw.disconnect(sample_frame)\n\tquit()\nfunc sample_pre_draw():\n\tTrace.mark("render_pre_draw")\nfunc sample_frame():')
    (target / "tests/profile_v49_hitch.gd").write_text(profiler)
    (target / "v49-hitch-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(prepare(args.source, args.output), indent=2))
