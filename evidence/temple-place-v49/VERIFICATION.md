Temple place sequence v49 - handoff
==================================

Base: `a141b6cbe96c5143b23fefdaf9c809a90d3d3ae1`. Canonical remains `bad54d2cb650702306ebbfc56b7df5efb8a94c6d`.
The fetched `e860cb6d` follow-up changes only shared status/production documents and is preserved for parent integration.

Changed temple-only environment/helper: washing landing in existing water, open court stone courses, narrow articulated cloister masonry, low bank growth and water-walk courses, then sanctuary reveal. Existing large sanctuary and human door, collision/layout, main/alternate/hidden/boss paths, camera, opaque materials, combat/spawns/rewards/economy and 240-second contract are retained. No other region redesign.

Verified
--------

- Godot 4.6.stable.official.89cea1439, native Mac Apple M3/OpenGL Compatibility. Separate copies and unique QA userdata. Engine windows exited; source config and ordinary saves unchanged.
- Import plus 9 focused tests passed. Composition: 13,443 checks, 0 failures; 5,148 bounded camera rays, 23 existing blocked rays, 0 new obstructions. 213 nonowned runtime/config files remain byte-identical to base. Tested seven owned source files match this checkout; hashes in verification.json.
- Coplanar negative control detected 7 overlaps in rejected revision. Final overlap count 0. Independent mesh line-sweep union area delta 0.0; lift 0.72, terrain and collision unchanged.
- Before/after actual 960x540 and 1280x720 rendering: 17 normal-input route points per size (34 total), 88 PNGs per variant; labels hidden. Both active walking totals 76.30s (38.15s per size), delta 0.0s. Render errors 0.
- Bounded player scenery Body minimum 98.6998% -> 98.8180%; enemy Body and tell both 100% in six fixed samples. Raw Body including the existing crossing warning remains 94.0382%; that overlap is not repaired or described as world occlusion solved.

Comparison sheets (left to right, top to bottom): water landing / open court / cloister / water walk / sanctuary reveal / human door. Images are contact sheets of actual 1280 renders: [before](before-1280-sheet.png), [after](after-1280-sheet.png).

Reproduce in a fresh disposable project copy with unique `config/custom_user_dir_name` containing `TemplePlaceV49` (or the existing Linux runner's explicit isolated XDG path): import; run `--headless --script res://tests/verify_temple_place_composition.gd`. For render, set `REGIONAL_LANDMARK_OUTPUT` to a fresh absolute directory and `REGION_LANDMARK=temple`; run `--rendering-driver opengl3 --script res://tests/capture_temple_place_sequence.gd`. The render fixture freezes pressure and waits for the existing camera to follow; it does not alter runtime camera or teleport between walk checkpoints. Its separate static overview is explicitly marked.

Remaining
---------

Parent integration/full CI and Windows native, natural combat/long-session performance and human place/beauty/fun acceptance remain unverified. Automated checks are contract/visibility evidence, not aesthetic or fun PASS. No new package, merge or canonical movement. Shared DEV_STATUS update is returned only as `patches/temple-place-status-v49.patch`.

Dashboard: first-region representative art/place integration / temple sequence implemented and bounded Mac evidence complete / parent merge and integrated regression / human acceptance and natural combat pending.
