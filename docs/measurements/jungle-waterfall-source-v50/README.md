# v49 floating-waterfall correction — preparation only

Base: actual GitHub-fetched deployment `296bde54f987372750e652c608c62b8e6309192c`. Independent branch `codex/jungle-waterfall-source-v50`. **Engine runs:0. Prepared source, not adopted or renderer-validated.** The performance lane holds the engine slot. User app/window/saves and the earlier hidden worktree are untouched.

The previous helper placed every sheet at ground+100 with height180, independently of rock: top190 above the21-height southern rim, detached main mouth, and two sources in the middle of hidden pools. The committed v49 inherited native images confirm those detached starts (`evidence/hidden-combined-v51/native-combined/jungle-1280-main-undiscovered.png` and `jungle-1280-hidden-overview.png`). Those existing images are inspection references, not new candidate evidence.

| Drop | Prepared supported lip | Receiving surface |
|---|---|---|
| Main mouth | west edge `(1240,605)` of185-height northern rim; upper L-shaped stream stays on existing northern/eastern rock | existing entrance-side wet ground near `(1225,690)` |
| Main upper south | south edge `(1290,550)` of185-height northern block | ground strip between existing rock banks |
| Main lower rim | west edge `(1240,780)` of actual21-height rim; short21-height spill replaces fake180-height sheet | shallow wet ground west of rim |
| Main upper west | west edge `(1110,490)` of185-height northern block; roof branch joins upper stream | wet existing ground west of block |
| Hidden receiving pool | actual rock/pool boundary `(7820,1830)`; source/feed interpolate producer bank triangles | existing blocked first pool |
| Hidden return pool | actual rock/pool boundary `(8240,1130)`; source/feed interpolate producer bank triangles | existing blocked return pool |

`jungle_waterfall_sources.gd` builds one static ArrayMesh per original water node, with a supported upstream surface, thin lip, three-piece falling sheet and receiving film. Alpha/color remain authored water. No new rock, colliders, roof, particle, node, automatic fading, per-frame process or gameplay terrain records. Hidden height sampling uses existing producer profiles; no additional runtime BVH or whole-mesh scan. Avoiding BVH construction also avoids the construction cost described in the [Godot TriangleMesh API](https://docs.godotengine.org/en/4.6/classes/class_trianglemesh.html).

Changes are isolated to the sanctuary water mount/new source helper and dedicated checks. Shared sections, all layouts/portal4/encounter6/altar/reward/discovery/AI/abilities/economy/save/project config remain byte-identical. The existing flow already mounts the sanctuary helper, so there is no new shared-section patch. Include both game files together.

Engine-free command: `python3 scripts/verify_jungle_waterfall_source_static.py`. Passed declared lip/roof coverage, hidden blocked-bank→existing-pool endpoints, unique main4+hidden2, unchanged223 nonowned game/config files and two negative controls (legacy190 height above21 rim, legacy source inside pool). Static estimated water triangles72→80, nodes6→6; this is not FPS or lag-fix evidence. `static-preparation.json` pins SHA256 and scope. The first static runner failed because its literal reader did not expand FIELD_ENTRY; the reader was corrected without product changes.

Prepared but **not run**: `tests/verify_jungle_waterfall_sources.gd` checks actual mesh heads against actual rock triangles, emitted vertices, pool feet and raised-sheet negative controls; use a private project with custom userdata name containing WaterfallSourcesV50. `verify_jungle_waterfall_visibility.gd` now selects six authored source meshes and retains color/alpha/count/duplicates/moved-head checks instead of asserting the defective fixed BoxMesh coordinates/height. Its old-rim baseline is a synthetic opacity comparison, not exact v49→candidate physical-design evidence.

Remaining: Godot import/parser and source-contact tests; exact v49 baseline versus candidate native960/1280 at mouth/northern block/lower rim/both hidden pools and return; actor/enemy/tell/depth readability; bounded performance delta. No runtime/Godot/headless/native results are claimed. Serious lag and clear→next departure failure are separate lanes and not solved here. Main/production/canonical, deployment/package and newer temple/palace/character art are unchanged.

Parent message attempts returned `Transport closed`; no successful direct delivery is claimed. The prepared commit/patch and final response preserve the handoff.
