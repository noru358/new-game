# Hidden flow and labels — parent handoff

Source branch `codex/hidden-flow-v49`, tested final source `d9ead856d50a1a4e42cfba3f5b27d4f445a2840d` (main implementation `5cca186a572ab7f88c67ee98d5c57decd403e65a`); base `1aac501f097ff565f5fd249b9411ab91e64b3223`. `686228f1d2f7cad0f09311c2006f46c6c16ce9d3` has identical game files and different documents. Remote is `https://github.com/noru358/new-game.git`. This is a validation branch, not canonical, packaged, merged, or a new user delivery.

## Actual active anchors (ground units)

| Contract | Temple circuit | Jungle south circuit |
|---|---|---|
| Main entry trigger | Rect(1160,730,110,110); center(1215,785) | Rect(1250,630,100,110); center(1300,685) |
| Main return | (1310,920) | (1150,700) |
| Hidden arrival | (5840,1770) | (6290,2630) |
| Hidden exit trigger | Rect(5660,1690,100,160); center(5710,1770) | Rect(6100,2510,160,220); center(6180,2620) |
| Arrival center distance to exit edge | 80 | 30 |
| Actual altar | (8300,480) | (9860,440) |
| Old main/inside minimap marker | (3120,250) / (8300,480) | (1300,685) / (8870,440) |
| Main/hidden map bounds | Rect(0,0,4600,3500) / Rect(5600,80,3000,2000) | Rect(0,0,5600,3600) / Rect(6000,80,4200,2800) |
| Combat camera / hidden overview size | 9 / 37 | 9 / 50.4 |

All five anchors (entry/return/arrival/exit/altar) passed actual navigation clearance18 and30 in the baseline. Main return→entry, hidden arrival→exit and arrival→altar are connected. An idle1s does not bounce. Coordinates were **not changed** in this lane. Field state and display/player bounds were already correct; they are preserved.

## Confirmed causes and changes

- The temple main minimap marker is about1978.7 units from the active entry. The jungle internal marker is990 units from the actual altar. Parent mount reads `section.discovery_marker()` from `section.layout.ENTRY_TRIGGER` / `ALTAR`, explicit `in_garden` and discovery ID; it checks displayed bounds before drawing. No discovery marker exists before discovery. No coordinate-size inference is added.
- Temple `_build_garden` previously placed main clue plants at2990,350 and3040,155 although the active entry is1215,785. Clues now live in `main_entry_root`, positioned relative to the actual trigger. Hidden decor and altar/exit labels live in `hidden_visual_root`. The corresponding roots change immediately with field state.
- Exit labels previously stayed visible at90 height regardless of field/distance. They now use the actual exit center at70 height,28px/0.010 pixel size and a240-unit near gate, and hide on main field or overview. Existing brief text stays `회랑으로` / `정글로`; no discovery spoiler label is added.
- Facing now points away from the destination threshold into the arrived field. Existing teleport resets movement/dash/slash/recoil and immediately follows the actual arrival camera anchor. Input axes and movement are untouched.
- The approved normal-speed westward approach from1395,785 reproduced a temple enter at frame23 and automatic return at71 from the same held input. Default diagonal temple and jungle approaches did not reproduce that problem. `hidden_threshold_latch.gd` retains the0.8s cooldown and debounces the old held input. It re-arms after physical clearance of the exit area **and** distance from arrival greater than the actor radius, or changed movement direction/release followed by nonzero input. Release alone never permits a transition. Initial spawn clearance alone cannot re-arm it.
- A hidden-less wetland inherits the section. Null/root guards keep its refresh and discovery marker safe and empty.

## Parent mounts and art contract

`patches/hidden-flow-minimap-mount.patch` edits the shared minimap only. `patches/hidden-flow-temple-terrain-mount.patch` copies only old records enclosed by the hidden `FIELD_BOUNDS`, removes the stale main vestibule from the circuit copy, and adds the current threshold floor at `ENTRY_TRIGGER.grow(30)` at height0.5 (parent correction `0a644f8`, below the0.009m actor shadow). It adds no collider, changes no shared coordinate, and leaves the valid legacy temple vestibule intact.

The art lanes should attach their field helper under `hidden_visual_root` and entry helper under `main_entry_root`, preserving `_build_exit_label`, `_refresh_hidden_labels`, dynamic altar/wave anchors and `discovery_marker`. Their helpers may replace the old internal art loops and `_build_entry_clues`. Do not add another exit label or duplicate the old clue meshes. The space-story concept applies to these two places, not a universal requirement that every hidden space be an old ruin.

## Verification and limits

Official Mac CLI: `4.6.stable.official.89cea1439`. All engines run sequentially with unique `LoopConquestHiddenFlow/<token>` userdata and per-test profile prefixes in disposable copies. Source checkout/project configuration, existing app and protected saves are preserved.

`verify_hidden_flow.gd`:290 checks,0 failures; three normal-speed bidirectional cycles on both legacy and both active scenes, three held approach directions per active scene, idle/release-only/same-input re-press/quick changed direction, near/remote/overview labels, map anchors, camera/bounds, HP/build/run clock/currency/retry preservation and pause/card/retry guards.

Eight relevant fixtures passed: hidden flow, temple section, jungle section, discovery UI, world destination labels, temple circuit run, jungle south circuit, deep wetland run. Existing section fixtures cover awakening IDs, once-per-run revisit reward, save failure, boss HP/240s/retry and card preservation.

Fixed960/1280 native render:56 PNGs total,0 failures. The baseline24 and first candidate24 used the exact same fixed fixture (234/282 assertions); eight final near-exit follow-ups used source `d9ead85` after the tiny first candidate font was rejected by direct viewing (78 assertions). Final nearby exit words are readable at both widths without clipping or covering the player. Distance/field/overview gates remain unchanged. Final eight images and the16 unchanged candidate states were directly viewed. This is Apple M3/OpenGL4.1 Metal native viewport evidence, not a natural run or human place judgment.

The fixture separates only its own window's focus-exited callback and unpauses that fixture, identically on both sources. Existing hidden guard spawns are preserved and frozen before action; no product pause or OS focus policy is changed. The first48 captures partly overlapped another approved fixed fixture; no elapsed time is used as a performance claim. Every PNG/window size is asserted. The GUI/headless engines ended and slots were returned.

`save-isolation.json` confirms all56 protected normal/preview JSON files are byte-identical across native capture and final regression. Final `tested-source.json` hashes match the staged source, both parent mounts passed reverse-apply checks, and all eight regressions passed again on `d9ead85` with floor0.5 and final label size.

Art lane final assembly and full project CI are parent-owned. Natural play, story/place acceptance, final art integration, audio/long-run performance and human beauty/fun remain unverified here. There is no execution blocker. Known earlier waterfall slope occlusion is outside this lane and is not reported as solved.


## Reproduce

Use a disposable copy whose project `config/custom_user_dir_name` is a unique `LoopConquestHiddenFlow/<token>` before importing. Apply both mount patches to that copy, preserving the source checkout. Use the official CLI path given above with these options:

```text
--headless --editor --path <copy> --quit
--headless --fixed-fps 60 --path <copy> --script res://tests/verify_hidden_flow.gd
--path <copy> --fixed-fps 60 --windowed --resolution 960x540 --script res://tests/capture_hidden_flow.gd -- --capture-dir=<fresh-absolute-output>
```

Obtain the parent GUI slot before the last command. Add `--exit-only` after `--` for the bounded8-image label follow-up. Existing output is never overwritten. The built-in focus fixture policy is identical for baseline/candidate. Original baseline probe source is retained as `.gd.txt` alongside the coordinate/held-input JSON reports; copy it into a disposable baseline's tests directory to reproduce the pre-change checks.

Progress:3단계 첫 권역 제작·히든출입/표기 / 완료: 동적앵커·최소debounce·290국소검사·8회귀·56PNG / 다음: 부모아트helper장착·합본fullCI / 사용자확인: 자연플레이·장소감·미감·재미미검증.
