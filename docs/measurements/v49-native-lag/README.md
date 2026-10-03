# v49 Mac native lag investigation

Base: `296bde54f987372750e652c608c62b8e6309192c` (delivered v49). Minimal code commit: `1cd01604ea16a7cea0b0df50b2e3aa04c5a8c9d5`. Draft [PR56](https://github.com/noru358/new-game/pull/56) targets that exact source branch. No merge/deployment/art/character/palace edits.

## Confirmed cause and fix

`hybrid_height._draw_enemy_warnings` draws each EnemyZone's 48 ring segments. `_ring_segment_clear` repeats three layer-4 `clear_attack` rays per segment on every rendered frame, including unchanged centers/radii and overlapping circles. At 72 mixed-role enemies this made 2,387,858 calls in 20 seconds. The cache makes 2,054 calls in the corresponding instrumented candidate. Warning CPU time per call falls 3.6014 to 1.8558 ms (worst 6.775 to 3.314 ms). Total warning CPU over 20 seconds falls 6.781 to 4.439 seconds despite rendering more frames; AI physics remains 1.319 to 1.307 seconds. Timers are temporary QA wrappers, absent from product code.

The product diff is 61 lines in `game/hybrid_height.gd`: cache exact center/radius/segment results; inspect simulation-owned layer-4 body transforms, owner transforms, disabled state, shape RIDs and resource edits; refresh the body list on tree changes; bound the cache to 64 circles. Actor references are not cache keys. All warning vertices/colors and live damage rays remain unchanged. Camera, density, AI, geometry, quality, balance, saves and assets are preserved.

## Native evidence

Mac15,12 / Apple M3 / 8 CPU / 24 GiB. Official Godot4.6 `89cea1439`, OpenGL4.1 Metal / GL Compatibility, 1280×720, vsync1, screen60Hz, physics60, time_scale1. Each 0/8/72 condition warms5 seconds and records20 seconds of live AI/physics/wisp/warnings. Stationary stress uses synthetic huge HP and controlled enemy counts; it is not human play. No fixed delta/fixed FPS/headless speed is used as display FPS. Tests use an isolated UUID user directory.

Values below are wall-clock **frame_post_draw renderer submission intervals**, not OS-presented display FPS. This Mac GL path submits roughly120 draws/s on a60Hz screen and alternates short/long intervals. A mean8.33ms therefore does not establish120Hz visible output. Godot TIME_PROCESS/TIME_PHYSICS_PROCESS monitors are **one-second maxima**, not per-frame averages ([4.6 source](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/main/main.cpp)). GL GPU timer returns0 and is treated as unavailable, not zero GPU cost.

| Region / enemies | Before mean/p95/worst ms | After mean/p95/worst ms |
|---|---:|---:|
| Temple0 | 8.333 /13.521 /14.327 | 8.340 /13.573 /21.058 |
| Temple8 | 8.332 /13.415 /14.257 | 8.334 /13.337 /22.313 |
| Temple72 | 10.268 /24.275 /26.482 | 8.359 /11.103 /24.868 |
| Jungle0 | 8.333 /13.573 /14.037 | 8.331 /13.538 /13.948 |
| Jungle8 | 8.349 /13.369 /14.817 | 8.335 /13.253 /13.776 |
| Jungle72 | 12.854 /20.527 /30.489 | 11.271 /16.337 /30.479 |

72-enemy mean draw calls are temple403.75→401.40 and jungle636.31→632.31; nodes712.56→712.66 and1414.97→1413.75; active physics bodies73 in both; collision pairs123.08→112.55 and111.46→113.46. Variation comes from live AI/instance-ID steering/projectiles. This change removes repeated clipping work, not objects. Full monitor distributions and raw frames are in `summary.json` and `raw/`.

A separate65-second test uses ordinary Input actions, normal camera follow/attack and actual ambient spawn, seed481, actual start locations, auto-selected level choices and huge player HP. Game time advances64.92–64.95s. Temple before/after and Jungle after record0 focus resumes; **Jungle before records1**. Its resume timestamp was not logged, so the Jungle moving numbers are qualified observations, not a fully controlled paired comparison. The earlier statement that all runs needed0 resumes was incorrect. Both variants reach the same number of route checkpoints; exact end pose and AI/projectile schedules vary. Final uninstrumented comparison:

| Moving/combat/spawn | Before mean/p95/worst ms | After mean/p95/worst ms | enemies |
|---|---:|---:|---:|
| Temple | 8.350 /13.399 /78.168 | 8.350 /12.979 /87.752 |4–54|
| Jungle | 8.717 /12.872 /28.571 | 8.378 /13.257 /29.764 |4–53|

**Severe low-density lag is not fully reproduced or resolved.** Temple still has a single78–88ms hitch around15.4–15.5 seconds estimated from the5-second warmup plus sampled wall intervals, with11–12 enemies. Legacy samples do not record per-frame active game time or position, so the exact place/route checkpoint at that instant is unverified. Ray-cache optimization does not fix it. Its exact cause (resource/shader/driver/presentation/other) remains unproved. Do not attribute it to the user's other apps. A subsequent raw-column review found delayed viewport render CPU peaks75.109/85.110ms,6 rows after each hitch. This strengthens the renderer-path association; it does not prove shader compilation, GPU duration or whole main-thread cost. See `temple-hitch-plan.md` for the next single-run timeline and candidate discriminators. GPU time, user's exact window/fullscreen settings, long natural runs and human responsiveness remain unverified. The source engine is an official development binary, not the user's packaged release process.

## Validation and process safety

- Headless warning/cache contract:10,761 checks/0fail. Native:10,762/0fail. Covers fresh-ray equality, unchanged repeat requiring0rays, center/radius changes, shape size/transform, layer/disabled, add/free, bound and unchanged arrays.
- Native cached/fresh PNGs byte-identical; SHA256 `465bcefdde7dcca51909011fdf7d6c49b182337c2b847d2d18c29b9d68ce6a62`.
- Combat feedback, hybrid feedback, terrain coherence, role visuals, temple run, jungle south, corner AI:7PASS. Profiling scripts parse-only PASS. Full CI is not run here.
- A headless actor-depth invocation correctly rejected missing dedicated native output/user-directory setup; that attempt is preserved in its log and is not a PASS. The dedicated nine-pose actor-depth suite was not run for this clipping-only patch. The new native pixel equality test did run.
- Temporary measurement failures excluded: first normal-spawn attempt was focus-paused (verified screenshot/counters); one jungle attempt was interrupted during tool transport loss; a duplicate temporary instrumentation dictionary key was fixed before successful remeasurement.
- Initial read-only ps/top01:32:36 local:0Godot/LoopConquest,78.78%CPU idle. Final02:08:39 local:0engines,83.56%idle, no swap counter increase in either snapshot. These snapshots do not identify the cause of earlier user lag.
- Only one owned engine at a time, every native run≤79seconds and watchdog≤100seconds. No user app was launched/killed/modified. Hashes of all4existing user progression JSON files are unchanged. AGENTS/DEV_STATUS/MASTER were read; this exact checkout has no `.agents/skills`.
- Exclusive engine slot returned02:08:39 local. Parent/integrator send-message and PR attachment tools repeatedly failed `Transport closed`; final automatic delivery is the fallback. PR creation/push succeeded.

## Reproduction

Create an ephemeral copy of the exact source and set ONLY that copy's `config/custom_user_dir_name` to `CodexV49Lag-<fresh UUID>`, import it with official4.6. The profiler scripts refuse a normal user directory. Run sequentially:

```
godot --path <isolated-copy> --rendering-driver opengl3 --script res://tests/profile_native_lag.gd -- --output=<absolute.json> [--region=jungle]
godot --path <isolated-copy> --rendering-driver opengl3 --script res://tests/profile_spawn_lag.gd -- --walk --combat --region=temple --output=<absolute.json>
godot --path <isolated-copy> --script res://tests/verify_warning_clipping_cache.gd -- --pixel-output=<absolute-prefix>
```

The automated fixture explicitly resumes only its own scene after OS focus pauses. It does not manipulate OS focus or another application. Preserve this limitation separately from natural player input. Natural gameplay difficulty, complete campaign and restart bug are outside this performance patch.
