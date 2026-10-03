# Temple single hitch: existing evidence and next timeline

Prepared without launching an engine. Product code remains `1cd01604`; these additions are QA tools/evidence only. Parent owns slot allocation; another task currently owns the native engine slot.

## Recovered evidence

Zero-based rows from the original uninstrumented Temple raw files:

| Observation | Before | After |
|---|---:|---:|
| Largest post-draw interval | row1238,78.168ms | row1252,87.752ms |
| Approximate wall time (5s warmup + intervals) |15.396414s|15.520365s|
| Enemies immediately before/at hitch |11/11|12/12|
| Draw calls immediately before/at hitch |144/146|145/147|
| Largest viewport render CPU getter |row1244,75.109ms|row1258,85.110ms|
| Getter peak offset from hitch |+6rows|+6rows|
| Physics monitor maximum in approximate14–19s window |4.936ms|3.683ms|
| Focus resumes in entire run |0|0|

`temple-hitch-before.json` and `temple-hitch-after.json` retain neighboring rows and field definitions; `tests/analyze_v49_hitch.py` reproduces them. The old sampler records no per-frame position or active game time. An exact court position/checkpoint cannot be reconstructed from final position, route and a seed because live steering varies. The earlier wording “first court approach at15.4 active seconds” was too definite.

The same-row renderer getters0.551/1.012ms do **not** exclude a rendering stall. The source verifies delayed capture handling:

- [GLES3 Utilities](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/drivers/gles3/storage/utilities.cpp), `capture_timestamp` and `_capture_timestamps_begin` around303–355: CPU values are clock timestamps and results are retrieved from a rotating buffer. [Utilities header](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/drivers/gles3/storage/utilities.h),166–183: three frame buffers.
- [RenderingServerDefault](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/servers/rendering/rendering_server_default.cpp),112–146: the post-draw callback precedes viewport timestamp handling in the non-threaded path.
- [RendererViewport](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/servers/rendering/renderer_viewport.cpp),297–302/666–670: begin/end timestamps bracket viewport drawing; `handle_timestamp` later copies them into the getter state.

Both renderer peaks align with the isolated hitch after the same6-row delay. This is evidence of a renderer-path association, **not** proof of GPU duration, shader compilation, resource loading or full engine main-thread cost. Physics monitor values are one-second maxima, not that frame's physics timer. Existing OS CPU snapshots are one-second aggregates and the earlier stack sample was a different stationary stress run; neither identifies this hitch's call stack.

## Candidates and discriminators

| Candidate | Existing source/evidence | One-run discriminator |
|---|---|---|
| First wisp hit and new pulse/transparent render path | `hybrid_height._on_wisp_hit` creates `_flash` and another sphere, then tweens its transparency. Two new draws fit the observed+2, but this is not an event match yet. No old hit-event timestamps. | Record first `_on_wisp_hit`, `_flash`, `_sphere`, player hit, and actual render pre/post wall timestamps. If no wisp hit occurs at the long draw, reject this event hypothesis. If timing matches but script spans are small and draw span is large, keep renderer/driver variant or upload as candidates. |
| First visible scenery/shader/geometry upload | Court/sanctuary/groves/place meshes are built in `_build_terrain` during ready. No15-second build trigger. First camera visibility still differs from creation. | Per-frame player/camera/route positions distinguish a place crossing from a first hit. Event-free long draw at a reproducible place keeps visibility-related renderer work viable. Proving compilation vs upload needs a hitch-aligned native stack trace. |
| Synchronous audio load | `player._play_sound` does `load(path)` during play; hit.wav may first be used at first close combat. Small surrounding physics maxima weaken but do not alone eliminate it. | Wrap `_play_sound` including stop/load/play; retain path and span. A long call at that event supports audio loading; a small call falsifies that direct CPU-cost explanation. |
| Spawn search / AStar / fixture waypoint | `_choose_spawn_point` may make up to60 path searches; fixture `steer` recalculates route paths on arrival. Same enemy count does not exclude scheduling or simultaneous removal/addition. | Wrap spawn selection/scheduling/creation and all `find_path`; record pending spawn count and waypoint. Long path spans and their origin markers distinguish game spawn/AI from fixture-only steering. |
| Runtime scene generation / first hit texture generation | Main scene/garden scenery are built in ready. Fragment role is the only ambient role before45s; configure eagerly calls `_texture(role,true)` and `_warm_enemy_rendering` does this at startup. | Startup and subsequent `_texture` spans provide evidence of actual call cost. Large live texture call would contradict the expected eager cache. No speculative cache/quality change yet. |
| Label/glyph creation or driver/presentation wait | Renderer CPU peak and two new draws cannot distinguish these. Existing steady-state sample has GL swap waits, which are normal under vsync and not proof of this hitch. | A long pre/post span with small measured script spans supports the engine/renderer boundary. Current script APIs cannot identify the native subcall. Reserve an8-second owned-process stack sample around12–20s for a separately approved slot if needed. No vsync/resolution/renderer change in this first run. |

Player hitstop only changes attack elapsed time (`player._advance_attack`); it does not block the engine or explain a78–88ms wall interval by itself.

## Slot-assigned single trace result

Parent assigned a native slot after the integrator returned it. This is the original cache candidate's product source `1cd01604`, QA copy from evidence HEAD `5006b8e` plus21 wrappers; **not** integration candidate `a665eff`. Official4.6/GL Compatibility/1280×720/vsync1/physics60/time_scale1/seed481 match prior runs. Source/copy manifest is preserved locally. No product changes were added.

The sampled hitch was reproduced: post-draw interval83.892ms at row1252; render pre→post83.068ms; delayed viewport CPU81.398ms at row1258 (+6 rows again). Exact trace clocks are relative to fixture initialization:

| Boundary/state | Observed value |
|---|---:|
| Previous post-draw |16.035692s|
| Target pre-draw |16.036514s|
| Target post-draw |16.119582s|
| Process/draw frame ID |1811|
| Physics frame ID |926|
| Game time at target |15.4166667s|
| Player / camera |(2046.728,943.9999) / (34.00865,14.21401,23.43998)|
| Route / waypoint |6 /14|
| Enemies / pending spawns |12 /0|
| Attack step / XP / level |2 /2 /1|

This is the **late route toward(2650,1000)**, rather than the earlier assumed first court approach. The marker data establish position/time for this trace only; old uninstrumented files have no such fields.

The measured scripts execute **before**, rather than inside, the83ms pre/post bracket. In that same iteration,44 recorded calls have a0.734ms union of clock spans (their naive nested sum1.548ms double-counts work). The prior post→current pre gap is0.822ms. Derived `_process`0.443ms contains base `_process`0.436ms, which contains `_draw_attack_at`0.262ms; these are **not three separate contributions**. Region physics0.108ms includes its base0.071ms and section tick0.023ms. Other actor callbacks are separately included in the union. These measurements rule out these sampled script calls as the direct83ms CPU span; they are not whole-engine main-thread/GPU measurements and do not cover every node callback.

**First-wisp-hit/pulse hypothesis is falsified for this hitch.** First `_on_wisp_hit` starts3.032086s (well before the target); the preceding hit starts15.501691s, ends15.501896s, creates its pulse by15.501883s; the next hit starts17.486624s. No new sphere/flash/hit is created during the target iteration or draw interval. Likewise no player hit callback was recorded anywhere in this run. The nearest sound call starts15.819990s and costs0.445ms, and the next is16.552460s. The nearest preceding path calculation ends16.019503s (0.026ms); the next starts16.119703s after the stall. The next spawn scheduling event starts16.185830s, also after it. None provides an83ms script span coincident with the hitch. A+2 draw-call change cannot be read as proof of two new pulse objects.

The evidence now narrows the target to **work/wait inside the renderer pre/post bracket**, with a matching delayed viewport CPU peak. First-visible geometry/material/glyph work and driver synchronization remain candidates. The trace does not identify a native subcall, GPU duration or shader compiler. A hitch-aligned native stack capture around12–20s at this location is the next discriminating measurement if separately assigned; no speculative pulse warmup, art removal, density reduction or renderer switch is justified by this run. No further engine was started after slot return.

Limits and failures are explicit:

- The first attempt failed before gameplay because the QA generator inserted an inherited constant twice. It was fixed only in the QA generator/copy; actual temple scene script parsing then produced no errors. Godot check-only sometimes returned0 despite dependency errors, so logs were inspected. The failed attempt's35s owned-process watchdog terminated it and its log/meta are retained.
- The observed run saved complete23.9833 active seconds /2272 sample frames /focus resumes0 to JSON. The80,000-event cap was reached at22.602769 trace seconds, **after** the16.036–16.119 target, dropping12,608 later events. The target and its neighbor/event evidence are present. This is not a complete24s timeline, and the analyzer excludes startup draws from the sampled-ranking list.
- **After writing the JSON**, native Godot cleanup crashed with signal11 in `GDScript::cancel_pending_functions`/`GDScript::~GDScript`/`ObjectDB::cleanup`; process exit-6 after25.655s. The timeline was already stored, but this is **not** a clean end-to-end PASS. The next generator removes its anonymous pre-draw lambda and disconnects QA render callbacks at quit; that cleanup adjustment has **not** been engine-tested. The crash's exact cause is unproved and should not be presented as a product bug fix.
- Original4save JSON hashes before/after match. Owned native PID25738 exited; read-only process check confirmed no Godot/LoopConquest. Slot was returned immediately to the parent; the integrator now owns it.

Raw data/log/meta: `hitch-candidate-single-valid*`; “valid” in the filename means the scene ran and wrote its sample, not a full validation verdict. `temple-hitch-aligned-window.json` contains the targeted draw, all nearby events and same-iteration spans; `hitch-candidate-single-analysis.json` is the reproducible summary. No user app or save was modified.

## Prepared code and one bounded run

`tests/prepare_v49_hitch_probe.py` copies a source tree into a new directory, assigns a fresh `CodexV49Lag-UUID` user directory, and adds21 timing wrappers to **that ephemeral copy only**. Base/derived wrapper names differ to preserve super dispatch without recursion. No scene geometry, enemy budget, sound, warning mesh, texture content or quality is changed. `tests/fixtures/v49_hitch_trace.gd` keeps bounded events in memory and writes at exit; no per-event disk logging or screenshots during the sample. Markers record clock timestamps and engine process/physics/draw IDs, while post-draw context records active run time, player/camera position, route/waypoint, XP/level/attack state, pending spawns and enemies. The analyzer reports longest script spans and render pre/post intervals. Nested spans must not be summed.

Prepared candidate copy: `/Users/lty/Documents/Codex/2026-10-04/task-3/qa/hitch-prepared-5006b8e`, with `v49-hitch-manifest.json` source hashes and its new save directory. Python AST and generated wrapper structure checks pass for all21 methods. **Godot parsing/native execution has not run**, in accordance with the engine-slot hold.

After explicit parent slot assignment, first parse the prepared script in the isolated copy (this starts an engine and therefore is also slot-gated). Then run one24-second candidate scene, normal ambient spawn/AI/Input/combat/seed481,1280×720/OpenGL/vsync1/physics60/time_scale1. A35-second watchdog manages only that process. Five-second warmup plus19-second sampling covers the expected hitch and delayed getter. Use the exact engine binary from the previous runs. Never read/write the user's live save directory.

```
godot --path <prepared-copy> --rendering-driver opengl3 --script res://tests/profile_v49_hitch.gd -- --walk --combat --region=temple --output=<absolute.json>
python3 tests/analyze_v49_hitch.py <absolute.json> --output=<analysis.json>
```

Acceptance is an aligned timeline, not a performance victory: no focus resume, no parse/runtime errors, event buffer not exhausted before the hitch, no change to player routes/game settings, and one expected low-density hitch (or explicitly record a failed reproduction). Instrumentation overhead affects absolute timing; compare causes/event order, not uninstrumented FPS. If no matching event/long draw exists, do not implement the pulse theory. If a first pulse coincides with a long draw, that establishes association only; a native stack or one tightly targeted subsequent comparison is required before a root-cause product change.

## Correction to Jungle moving comparison

`raw/baseline-walk-jungle-clean.json` records `focus_resumes=1`; the after run records0. The old “all0” statement was incorrect. No resume timestamp was captured, so its placement inside warmup/sampling cannot be established. The8.717→8.378ms mean and28.571→29.764ms worst remain observed values, but **are not a fully controlled paired comparison**. Temple and the stationary0/8/72 comparison are separate evidence. No replacement measurement is authorized until parent slot assignment.
