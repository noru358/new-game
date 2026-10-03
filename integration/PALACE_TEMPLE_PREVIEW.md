# Palace temple first checkpoint — 2026-10-03 UTC

Follow-up source/approach/headless results: `PALACE_APPROACH_READY.md`. The first screenshot limitations below are preserved as historical evidence.

Independent branch `codex/palace-temple-preview-oct03`, cloned from latest playable candidate `296bde54f987372750e652c608c62b8e6309192c` / draft PR54. Actual remote owner and connected user are both `noru358`; production `1aac501f097ff565f5fd249b9411ab91e64b3223` is an ancestor. No main/production/canonical change or campaign mounting.

## Scope and implementation

Southeast Asia -> maintained royal palace temple candidate -> processional gate / bright paved court / shaded cloister. New isolated terrain, kit, scene and capture helper only. Existing 2D ground movement, 3D presentation, camera9 / offset(14,13.864,14), player sprite scale, direct melee, frequent short dash, moving slash, existing enemy AI and no automatic transparency. The current player remains the existing placeholder; reference character is not copied.

Original upright angular guardian forms: turquoise/vermilion paint, oversized tusks, paired shoulders, brass breastplate, centered club, stepped crown. Three layered painted roofs, ivory gate piers, rear five-bay gallery, distant raised hall. Quiet courtyard center; large forms at rear/side. Single flat walk surface at height0; paving top0.5–0.95px below shadow lower surface1.2px. No raised walk layer or occlusion fading.

Inherited laboratory player/growth objects are used, with progression ended and no reward callback. Enemy health/AI reused; three existing role instances spawn in court for development combat. `--palace-walk-only` suppresses them for the documented input walk. No campaign timer, boss, new profile, economy, unlock or hub connection.

## First actual result

Tested game code: `9c3a9d956d49596365779852d4ad69ee2b4172e6` (first commit also stores capture evidence).

Official engine copy matches existing task10 receipt `integration/HIDDEN_COMBINED_V51.md` line66: version `4.6.stable.official.89cea1439`; executable SHA256 `974197a7e6663dba803ae97c3b2d987b77a37b6e70088400ecf0ccc591cbdfbc`. This request verified copy hash and `--version`, and read the prior verification receipt. It did not repeat official archive download verification. Official upstream release: https://github.com/godotengine/godot-builds/releases/tag/4.6-stable .

One engine at a time, parent-assigned headless1 then GUI1. QA copied game/tests/project into `qa/first/project` outside this repository; only the copied config custom userdata was changed to a unique `CodexPalace/<UUID>`. Original `project.godot` and user saves preserved. First sandbox import had invalid absolute custom userdata mapping and denied creation; raw `initial-import-userdata-error.txt` retained. The subsequent corrected UUID headless and native executions both exit0 / script errors0. No manual OS focus or CUA use.

- Headless: actual Input actions reached6 targets in7.4167 active seconds.
- Native: actual Input actions reached6 targets in7.4667 active seconds; gate→court→cloister.6 target actual positions and per-leg times are in `evidence/palace-temple-first/report.json`.
- Three bounded `force_draw(false)` PNGs, verified960×540 / nonempty bytes: gate127773, court102291, cloister124973.
- Kit12420 vertices /6 mesh instances. Capture profile group0; this is not a comprehensive save regression.
- Own engine0 and whole-Mac Godot0 checked after native termination.

## Visual judgment and next step

Actual pixels were viewed. The cloister reads as repeated pillars, painted roofs and a quiet shaded walk. At the first gate capture, actor(1436.796,1550) has already passed the gate, and tall guardian heads / roof upper tiers are heavily cropped. The first landmark framing goal is therefore **not met**; input PASS is not art approval. Do not adopt this current framing as completed palace art.

Next: preserve this first evidence, then evaluate the entry-side representative camera view and lower/recompose gate roof height within current camera contract. Keep a pair of large guardians visibly framing the passage. Do not zoom out, move the camera, add dozens of props or run broad regression before this visual goal is met. Request another GUI slot before native recapture. Head-height ray checks, actual actor mask visibility, short-dash/melee combat and1280 check remain pending.

Human place/aesthetic/fun, natural combat, entire map, campaign completion, long performance, packaged application and user first launch are unverified. No package or merge was made.

## Private reference

Library `libfile_c133c83688a88191860593ccc3bc20a7` was materialized through current Library skill `prepare_materialize` + unchanged bundled helper using available Python3.12. First systemPython3.9 attempt had a type-union error and was retried with3.12. Final consumer-local file exists/readable:3051100bytes; actual pixels viewed. It remains outside repository at task-2/private-reference/exec-5fa51b3c-b072-4aa3-a56e-015495c42577.png. No original reference bytes uploaded to public GitHub.

## Run

Use an isolated copy and UUID `config/custom_user_dir_name` before running. Development direct scene is `res://game/palace_temple_preview.tscn`. Normal controls are WASD / J / Shift / Space. Capture script is `res://tests/capture_palace_temple.gd`; set `PALACE_CAPTURE_DIR`, run with `-- --palace-walk-only` for native, adding `--palace-headless-check` for non-rendering checks. Bounds:720 frames per walk leg,8 process frames before `force_draw`, native engine `--quit-after 1800`.

Progress dashboard: current3-stage content/art, Southeast Asia palace representative slice / done independent silhouettes and first real-input960 walk / next fix entrance framing and ray/actor/combat checks / human approval and visual goal remain unverified.
