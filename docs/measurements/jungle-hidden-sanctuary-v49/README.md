# Jungle waterfall sanctuary — parent handoff

Base: `1aac501f097ff565f5fd249b9411ab91e64b3223` on `codex/first-region-production-v44`. Actual GitHub clone, canonical ancestry, and merged PR53 were checked. Canonical `686228f1d2f7cad0f09311c2006f46c6c16ce9d3` differs only in three shared documentation files. The user app/canonical remains v48. Branch: `codex/jungle-hidden-sanctuary-v49`.

Southeast Asia → jungle → a short rock threshold beyond the waterfall, then a receiving pool and a small root-held water sanctuary. This is this hidden place's specific character, not a rule that all future hidden streets must be ancient ruins.

The entrance path half-width changes 170→130; all five route spines, three original pools, two defender groups, their six exact coordinates/areas, the altar `(9860,440)`, field bounds and four portal values remain. Two adjacent blocked-water records describe the inlet and receiving pool. The long west route returns to the same mouth. No travel distance is added. Main jungle/tree/waterfall terrain remains unchanged.

`jungle_hidden_terrain.gd` marks the field's existing rock records for five opaque batched visuals and retains collision/minimap records. Two larger landmarks occupy already blocked northern-bank ground. Perimeter strips and grid banks share one partitioned blocked footprint. Neighboring bank surfaces emit only exposed side heights; exact common cell endpoints avoid subpixel slivers. The entire bank-generation path is checked for actual coplanar triangles, not just overlapping rectangles. The short passage has a permanently open southeast face and broken northwest lintel; no automatic fading or roof cutaway. Warm low courses at the opening and shrine differ from wet threshold stone. The offering bowl sits behind the original interaction point, with no new interaction/collider.

## Mount contract

Apply the three owned game files together with the parent flow mount; layout install suppresses the old field wall boxes in favor of the helper. A partial mount would leave rock-bank visuals missing.

The helper exposes:

```gdscript
hidden_visual_root = preload("res://game/jungle_hidden_sanctuary.gd").build(arena, layout)
main_entry_root = preload("res://game/jungle_hidden_sanctuary.gd").build_entry(arena, layout)
```

The flow lane adds these roots to the section, hides the internal root initially, and toggles the two roots by current field. It continues to own all labels, minimap destinations, transport and `altar_ember`. `integration/jungle-hidden.mount.patch` demonstrates replacement against v48; adapt that snippet to the flow lane's newer section instead of applying it blindly. It is a context-free unified diff; checking/applying to its exact base requires `git apply --unidiff-zero`.

Internal root: five static opaque batches plus the original two internal water curtains. Entry root: the original four main water curtains and three bushes, with exact v48 geometry, material and coordinates. Do not keep the old six-curtain loop as well. Authored alpha water is unrelated to automatic obstacle transparency.

The existing `verify_jungle_waterfall_visibility.gd` must search section descendants rather than direct children after the root reorganization. Its exact six-water/material/rim contract is unchanged. That lookup adaptation was made only in the disposable QA copy; the parent flow lane owns its committed integration.

## Verification

Mac Godot `4.6.stable.official.89cea1439`. Engine copied into this task so shared editor settings are not written. Separate baseline/candidate projects and UUID `JungleHiddenV49` userdata; user apps/windows/saves untouched. No CUA.

- Final geometry/impact fixture: 7,008 checks, zero failures. Route/defender/altar/exit round trips, collision/minimap bank agreement, single walkable ground height 0, actual projectile visual lift 55, actual 2D water collision ray and attack-sight blocking, and original reward/return.
- 1,268 dense camera rays at four actor heights; 20 existing bank-box occlusions and zero additional helper obstructions. This is a bounded geometry check, not a whole-map visibility claim.
- Existing jungle section (discovery, two waves, save failure/once-only awakening, revisit healing and main return), south circuit, river route, waterfall visibility and terrain coherence passed before the final surface-only correction. Those prior successes are retained without another full suite. The final source was parsed and rechecked by the 7,008 geometry/impact assertions, including unchanged route connectivity, actual collision/minimap, reward/return, projectile height and 1,268 camera rays. Root-descendant waterfall lookup was adapted only in QA.
- Reused pre-correction normal-speed headless input: 36 checkpoints (18 at each 960/1280), actual section entry and return, 80.3667 active walking seconds, 112.20 wall seconds, zero errors. Time/spawn pressure is frozen, with no walking acceleration or waypoint teleport; section transport uses the existing authored relocation. This is not natural combat or human input.
- 215 nonowned game/config files remain byte-identical to the base. Source `project.godot`, both section scripts, profile, rewards, enemy rules, AI, economy and abilities are unchanged in the owned checkout. The section mount lives only in disposable QA and the reviewable parent patch.

The unchanged pinned baseline native run completed 36 checkpoints / 84 PNGs at 960/1280, using 80.3000 active walking seconds. This exact run is reused; no baseline product or capture-fixture source changed. The exact final candidate native run is **incomplete**: 10 checkpoints /26 PNGs at960, through `10-shrine-lip`, then no further progress. After392.161 seconds the exact private QA command/PID95376 was rechecked and terminated with SIGTERM (exit−15). The GUI slot was returned; no full native retry was requested. `final-native-partial.json` records the precise last progress time, command and missing scope. The earlier candidate completed36 checkpoints /84 PNGs, but uses earlier bank geometry and lives under `prior-candidate/`; it does not certify final-source whole success. The fixture has equal focus-exit pause disconnection and initial pause reset in both variants, like the existing capture fixtures; no product/OS/user-app focus policy is changed or validated. Raw Body visibility, same-FX player, enemy Body and tell differentials are retained separately. Both variants use WINDOWED mode and five initial settle frames. No waypoint teleports, dash or time acceleration are used; configured MOVE_SPEED=300 and fixture saved multiplier=1.12 are shared. All captures freeze run/spawn pressure and briefly freeze geometry for pixel differentials. Normal section transport remains the existing authored relocation.

Initial failures are retained locally: native-class alias collision, fixture reward call before discovery tick, frozen cooldown at exit, simulation disable removing physics colliders, a zero-PNG native buffer-size mismatch, and the progressively strengthened geometry negative controls. The native window settle policy was corrected equally in both variants. Actual rendered duplicate foundation/perimeter faces and hidden shared bank sides were removed without moving props, adding sculpture or changing gameplay footprints. Final emitted vertical bank triangles have zero positive coplanar-area overlap; rejected uncut banks produce 1,584 pairs. Coincident cell joins use identical endpoints and the overlap oracle uses translated double-area products to avoid float32 cancellation. Those fixture problems were corrected; no reward, pause or physics product code was changed. First sandbox import could not write shared editor/private userdata paths; using a copied engine and explicitly approved unique private userdata resolved it. No automatic-review rejection occurred.

## Native stop diagnostic and evidence

The native log records completion of10 at `(9739.84765625,971.149963378906)` but does not trace each subsequent await, so the exact native blocking phase is unresolved. A short headless diagnostic reused the unchanged capture `_walk` from that actual last location to the altar. It reached `(9861.0341796875,439.656341552734)` in1.9833 active seconds /4.5371 fixture wall seconds, with zero actor error,0.000358 camera error and no failures. That diagnostic begins with an explicit setup relocation; it is not normal-approach or native-render evidence. Movement/collision failure was not reproduced. A renderer/window/frame-wait cause remains an inference, not a confirmed diagnosis.

Final native completed960 samples: same-FX player minimum0.9863158; fixed real enemy Body and actual tell each1.0. Raw player minimum0.8371628 at the unchanged actual main entrance is identical to the paired baseline; raw Body also retains other actor/FX overlap. No whole-map98% claim. Static hidden primitives at these paired samples increase2406–3570→8884–9176; draw calls198–206→199–204. This is a bounded static-cost comparison, not long-term performance acceptance.

Open [comparison.html](comparison.html) for final first10 checkpoints at960 or the clearly marked earlier complete geometry revision. [comparison.json](comparison.json), [tested-source.json](tested-source.json), [final-native-partial.json](final-native-partial.json) and [png-manifest.json](png-manifest.json) distinguish source hashes and reused/rechecked evidence.194 native PNGs are included:84 pinned baseline,84 prior candidate and26 exact final partial.

## Remaining

Final-source native11–18 at960 and all1280 are unverified; the parent integration lane will cover required segments on its final combined source. Parent flow integration, final integrated CI and native packaging; human beauty/place/fun acceptance; natural combat, long performance and focus behavior remain unverified. No main/production/canonical update, merge or package is authorized to this lane.

Dashboard: first-region representative place/art integration / jungle hidden implementation and bounded headless verification complete / remote source/evidence handoff to parent integration / human acceptance and natural combat unverified.
