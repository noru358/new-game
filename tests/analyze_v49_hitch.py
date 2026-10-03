"""Read saved native samples/timelines. This tool never runs Godot."""
import argparse
import json
from pathlib import Path


def analyze(report):
    frames = report["frames"]
    elapsed, times = 5.0, []
    for frame in frames:
        elapsed += frame[0] / 1000.0
        times.append(elapsed)
    hitch = max(range(len(frames)), key=lambda i: frames[i][0])
    render_peak = max(range(len(frames)), key=lambda i: frames[i][3])
    result = {
        "time_basis": "5-second warmup plus sampled wall intervals; legacy samples do not record per-frame run_time or position",
        "focus_resumes": report.get("focus_resumes"),
        "worst_interval": {"index": hitch, "approx_wall_seconds": times[hitch], "row": frames[hitch]},
        "max_viewport_render_cpu": {"index": render_peak, "approx_wall_seconds": times[render_peak], "row": frames[render_peak]},
        "render_peak_row_offset": render_peak - hitch,
        "neighbors": [{"index": j, "approx_wall_seconds": times[j], "row": frames[j]} for j in range(max(0, hitch - 4), min(len(frames), hitch + 9))],
        "columns": ["post_draw_interval_ms", "enemies", "one_second_max_physics_ms", "delayed_viewport_render_cpu_ms", "draw_calls"],
        "caveat": "Same-row render time is a delayed getter; no GPU or whole engine main-thread measurement.",
    }
    trace = report.get("timeline", {})
    events = trace.get("events", [])
    if events:
        ordered = sorted(events, key=lambda e: e[1])
        first = {}
        render = []
        pre = None
        for event in ordered:
            first.setdefault(event[0], event)
            if event[0] == "render_pre_draw":
                pre = event
            elif event[0] == "render_post_draw" and pre is not None:
                render.append({"ms": (event[1] - pre[1]) / 1000, "pre": pre, "post": event})
                pre = None
        result["timeline"] = {
            "dropped": trace.get("dropped"),
            "first_events": first,
            "longest_script_spans": sorted([e for e in events if ":" in e[0]], key=lambda e: e[2] - e[1], reverse=True)[:20],
            "longest_pre_post_wall_intervals": sorted(render, key=lambda e: e["ms"], reverse=True)[:10],
            "longest_sampled_pre_post_wall_intervals": sorted(
                [item for item in render if item["pre"][1] >= first.get("frame_sample", [None, 0])[1]],
                key=lambda e: e["ms"], reverse=True)[:10],
            "limits": "Script spans overlap; do not sum nested spans. pre/post boundaries include renderer work/waits, not GPU-only time. Use event IDs, wall timestamps and per-frame run_time rather than delayed viewport getter for alignment.",
        }
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    text = json.dumps(analyze(json.loads(args.input.read_text())), indent=2) + "\n"
    if args.output:
        args.output.write_text(text)
    else:
        print(text)
