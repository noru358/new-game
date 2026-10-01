# Loop Conquest — Consolidated Playtest v38

Includes the canal synthesis, corridor and sanctuary environment sample, movement-link/retreat-keyboard fixes, close-boss player visibility, export cleanup, and three isolated permanent-price comparisons. Ordinary `godot --path .` keeps existing saves and baseline prices.

Start a **fresh separate trial** (Godot 4.6.x on PATH):

```sh
python3 scripts/launch_price_trial.py late3
```

Use `python` on Windows if that is its Python command. Choose `baseline` (20/35), `late2` (20/70), or `late3` (20/105). These are first/second-rank permanent-growth costs; first weapons, XP, healing and combat are unchanged. `late3` is the sharper specialization comparison, not a final balance decision. If Godot is not on PATH, add `--godot "/path/to/Godot"`; macOS may pass the actual Godot.app path.

The launcher prints the copy/save locations and a complete resume command. Keep the trial copy at that location; resume with the same curve and printed `--destination ... --resume`. Each candidate starts without money, gear or unlocks. Use the launcher to resume, so its private environment and profile identity stay consistent. It never edits the source project or reuses ordinary campaign saves. A changed/moved copy or different curve is refused; choose a new destination for another trial.

Use WASD, J/click, Space moving slash, Shift dash, E interaction, G retreat. Buying gear and equipping it remain separate actions; retreat supports Tab/Enter and Escape.

Batch playtest agenda (human judgment remains open):
1. Does the canal market→warehouse→waterfront read as connected, distinct places during combat?
2. Does the gallery→sanctuary reveal read as a place while keeping the boss, attack warnings and escape space clear?
3. Is moving slash→empowered basic→cooldown refund understandable and useful?
4. Do second-rank prices70/105 create worthwhile priorities while first improvements and weapons remain accessible?
5. After success or return, is the reward→purchase→equip→next-run difference clear and worth repeating?

During close boss overlap, the existing player sprite is temporarily drawn in front so its position and pose remain visible. Temple and jungle restore normal depth as soon as that occlusion clears; boss silhouettes, warnings and combat rules stay the same.

The sanctuary adds a side chamber and ruined gallery beyond the existing sealed court edge, quiet paving, and selective sight protection. It is a representative environment step; final actor/boss art, sound and the complete first-region presentation remain unfinished. A developer comparison keeps the previous corridor kit: `godot --path . res://game/hybrid_region.tscn -- --sanctuary-baseline`. The older `--temple-baseline` still removes the whole environment kit.

The engine checks establish isolation, displayed/charged prices, respec and reload. The budget study combines actual scripted success/retreat/loss awards with fixed-budget arithmetic; it does not establish human saving pressure or a closed-loop winning price. See `docs/PRODUCTION_NEXT.md` section15 and `docs/measurements/price-v35/`. Native macOS device/audio/long-session GPU validation remains pending; Windows runner evidence is headless and linked from the PR.

# Loop Conquest — Build and Economy Check v34

This checkpoint keeps v33's game and environment, explains the moving-slash weapon's +25% follow-up and 0.22s cooldown refund, and repairs keyboard focus/confirmation in the retreat dialog. No combat or economy values changed.

Run Godot 4.6.x with `godot --path .`. Use WASD, J/click, Space moving slash, Shift dash, E interaction and G retreat. The retreat dialog now supports Tab and Enter; Escape cancels. Buying gear and equipping it remain separate camp actions.

The normal-speed samples in `docs/measurements/build-v34/` test existing mechanics and persistence. They are scripted input, not human fun, art or balance acceptance. The three fresh temple runs are actual earned progression; the three equal-investment grown loadouts use explicitly synthetic prior history. See `docs/PRODUCTION_NEXT.md` section14 for results and the next bounded comparison.

Manual sample tools require a fresh explicitly isolated user-data directory and refuse existing campaign slots. They are not player-facing save presets. See each script's invocation contract: `tests/sample_build_comparison.gd` and `tests/sample_fresh_economy.gd`. Do not use ordinary saves for diagnostic fixtures.

# Loop Conquest — Temple Environment Sample v33

This package includes the v32 canal-town synthesis and the next **partial temple environment kit**. The existing temple corridor and sanctuary entrance now use worked stone, paving and restrained growth, with one taller ruined threshold member. This is a small production sample; the full temple art, sound and vertical slice remain in progress.

Run normally, then enter the existing temple from camp. To compare the original visual baseline in a new process:

```sh
godot --path . res://game/hybrid_region.tscn -- --temple-baseline
```

Without that developer argument, the kit is enabled. Camera, movement, terrain barriers, hidden-field routes and saved progression follow the existing game. The taller member selectively fades for the player and visible enemies; other masonry stays solid. No new progression/menu option is added.

`tests/verify_temple_environment.gd` checks actual route/attack/field/boss contracts. `tests/capture_temple_environment.gd` needs a graphical display and records matched inspection frames; simulation and existing warning poses are held for comparison, so these are not human play/performance recordings. Set `TEMPLE_CAPTURE_DIR` to an absolute output path. Windows runner export/startup results are linked from the PR; interactive device, audio and sustained GPU acceptance remain separate.

---

# Loop Conquest — Jiangnan Canal Town v32

A bounded, playable **place-authoring experiment**, not finished vertical-slice art or a new campaign region. The v25 temple/jungle implementation and v26 production direction are preserved. The closed, unmerged v27 camera experiment is not included.

## Run this trial

Requires Godot 4.6.x. From this project folder:

```sh
godot --headless --editor --path . --quit
godot --path .
```

In camp, approach departure and press E, then choose **개발 시험 · 수로도시 장소 경험 (저장·보상 없음)**. Direct entry:

```sh
godot --path . res://game/canal_city_trial.tscn
```

WASD / Shift / J or click / Space retain the current movement, dash, direct attack and moving-slash controls. F2 switches scenery/limited existing enemies; N resets the eight fixed opponents; R restores the fixed practice loadout at the east gate; Tab shows the authored layout; Esc pauses; G or the camp button returns. The three top buttons are comparison checkpoints, not campaign travel unlocks. The trial has a fixed four-hit/moving-slash practice loadout, no XP, economy, boss, settlement, profile writes or save unlocks. Existing temple/jungle progression remains unchanged.

The design follows **China south → Jiangnan reference region → canal town → east gate / market / cargo quay / sluice court → buildings and props**. The regional identity uses low white plaster walls, dark tiled roofs, narrow canals and short stone bridges. A’s shop architecture joins B’s connected streets and meaningful goods clusters: produce/pottery/cloth stock at shop fronts, warehouse cargo beside its handling lane, and a small fixed landing facing the nearby opposite bank. The 7200×4800 v2 connections and current gameplay camera/movement remain. Cached alpha materials fade only foreground architecture covering the player or nearby on-screen enemies in Compatibility, preserving collision and restoring solid materials when clear. These are representative meshes; human place appeal and combat feel remain unverified.

Automated 60Hz input-driven traversal, with current speed/camera and no enemies or viewing dwell:

| Route | Walk | Frequent dash |
|---|---:|---:|
| East gate → market | 18.25 s | 14.27 s |
| Market → quay viewpoint | 11.53 s | 8.97 s |
| Quay → sluice → east gate → warehouse return → market → quay | 47.73 s | 37.50 s |

These are navigation-shortest locomotion measurements plus a fixed waypoint return loop, not a human exploration/playtime result. Reproduce with `godot --headless --fixed-fps 60 --path . --script res://tests/measure_canal_city.gd`. `verify_canal_city.gd` checks save-byte isolation, terrain, bridge round trips, six existing chasers passing the bridge, open market/cargo connections, foreground player/enemy visibility and material restoration. `capture_canal_city.gd` needs a real graphical display and writes actual engine screenshots including a clear street viewpoint, warehouse, market/waterfront combat and 960×540 fit; set `CANAL_CAPTURE_DIR` to an absolute output folder.

Validated common patches are integrated: permanent-card unlock notices and compact equipment fit from v29, opt-in local run diagnostics and truthful jungle encounter cues from v30, and v31 Windows export/startup automation. No balance or save-policy change is included.

Package scope: runnable Godot source. Linux 4.6.3 GL Compatibility images use actual llvmpipe rendering. The Windows CI exports and headlessly starts the exact commit on a Windows runner; consult the PR for its result. Interactive Windows device/GPU tests, audio listening, sustained performance and a new macOS signed/notarized package remain unverified. `DEV_STATUS.md` records the local verification and next production work.

---

# Previous playable baseline: Readability & Jungle Density v25

The v25 trial presents each discovered place and awakening as a compact card with its core effect, active state and next action. Camp gear shows the chosen item, awakening and replacement options together. The live HUD shows an XP bar beside the current level. The fourth basic hit no longer enlarges the player model. Near-side walls in both hidden fields are lowered while collision remains, and the jungle boss court's obstructing structures are reduced or moved. Ambient enemy spawn rates and the ordinary enemy cap are 1.5× the earlier baseline (72 cap), with closer spawns; the jungle forest, ruin crossing and riverbank use distinct low scenery and enemy mixes. These are playtest values; human difficulty and readability are pending.

The jungle grotto is a fixed 4200×2800 exploration field: a winding stream, branching ravines, open pools, inner ruins and a western return passage. The first visit targets 2–3 minutes; this is a playtest target, not a measured duration. Reach the inner ruins and press E for the permanent echo-weapon awakening. The two local enemy groups may be fought or avoided; no kill quota or puzzle gates the reward. The temple garden keeps its three-guardian challenge. Repeat grotto visits can heal 20% maximum HP once per run at the ruins.

Permanent awakenings now have a paused acquisition comparison, a camp discovery record and equipped/inactive status. Unknown places and reward totals stay hidden. Camp gear shows effects, awakening and replacement options together; growth separates attack, defense and mobility. Combat HUD groups health and current location, boss/timer, and run growth; pause has card, gear/awakening and controls tabs.

Boss counter windows now reward direct attacks with 30% additional damage and a brief local impact reaction without extending recovery. The temple retains charge/pulse pursuit; the jungle alternates its front sweep with an outer wind ring whose inner area is safe. Approved trial HP is 1800/2000, informed by a synthetic ten-card mixed-build damage probe; human fight duration and enjoyment still require playtesting. Profile v6 and its existing save directory are unchanged; older v1–v5 records can be read, but old builds cannot read v6 saves.

Godot 4.6 combat and terrain prototype. The default scene is `game/travel_camp.tscn`: walk between the region map, equipment/growth, and departure stations, then press E to open the corresponding preparation tab. Region 1 remains `game/hybrid_region.tscn`; a first clear opens `game/jungle_pass.tscn`, a cliff/jungle route climbing to a high gate. Movement, enemy routing and hit detection use 2D ground coordinates; terrain records supply height, walkability and line-of-sight boundaries for the 3D scene and minimap.

The waterside court is the detailed traversal test: lowland, raised court and upper terrace (heights 0/160/320), north/south/east ramps, six consecutive stepping stones, deep-water cuts and dry detours. Three later spaces now have distinct routes: the temple grounds split around a central ruin, the gallery has two lanes and a middle crossing, and the sanctuary has an open duel floor with its altar along the eastern wall. These three spaces are flat blockouts; their art and final geometry remain open. The minimap projects the entire region through the gameplay camera's axes, so its diamond and the white camera footprint follow the view on screen. The main combat camera is closer and slightly steeper than v08 (`size=9.0`, about 35° ground angle); Tab still shows the full map.

Each combat scene runs a five-minute round with denser timed spawning, up to 72 ordinary enemies at once. A warning precedes every visible spawn. At five minutes the first region's boss appears in the sanctuary after a warning and engages on entry; the second region announces a fixed gate spawn at 4:30 and places its boss in the upper court at 5:00. Region 1's gate boss uses a charge, central shock, and phase-2 outer ring. The jungle gate guardian uses a lateral sweep and an outer wind ring, with faster timing in phase 2. Killing the boss ends the run successfully; death and voluntary retreat also settle the run. The first lifetime level-up permanently opens Space moving slash and the third combo hit; the third permanently opens the fourth hit. Moving slash links after an attack, preserves the next combo step and briefly avoids damage at its start. Cards can widen the slash or shorten its cooldown. Level-up choices include a manual-attack card and a wisp card while either branch remains available; a third comes from the full pool. Two cross-branch cards make manual hits advance wisp fire and wisp hits advance moving slash cooldown. A level-up card shows the resulting value and can be rerolled once. The result screen shows earned, lost and banked currency: success keeps all earnings, defeat loses 50%, and retreat loses 20% (rounding losses up, while preserving at least one earned coin). These rates are playtest values. The prototype first-clear record is still named `RELIC_TEMPLE` internally for compatibility; a relic-based story is not decided. Permanent card and move unlocks currently use `user://loop_conquest_1d_unlocks_*.json`; the settlement profile uses `user://loop_conquest_profile_*.json` with a recoverable prior slot. The versioned app title keeps using the v03 user-data directory so existing saves remain available.

The third hit reaches 145 ground pixels before enemy body radius, then visibly pulls caught enemies toward a point in front of the player. Water and cliffs block both damage and the bright slash/warning displays; a separate airborne blade no longer implies range across deep water. The terrain data drives the visible geometry, collision and enemy routes. All 16 jungle tree blockers now have matching visible trees. The jungle gate's blockers rise above their walking surface, its columns share visible and collision records, and the lintel avoids coincident faces. The gate routes split mid-ridge: one reaches a broad stone stair, while the other skirts the southern cliff on three broad rock ledges and a rugged ascent. A continuous ridge wall prevents switching paths just before the gate; each route stages separate entry and crest encounters. Ramp edges are marked from the same route records. Walking and moving slash receive a small inward guide at ramp mouths, while wall collisions still block travel.

The earlier 2D temple map remains at `game/temple_region.tscn` for comparison. The focused height lab remains at `game/hybrid_height.tscn` and uses a separate local card-unlock record. The original combat sandbox is `game/main.tscn`.

| Input | Action |
|---|---|
| WASD | Move in camp and combat |
| E | Open a nearby camp station / claim a discovered ruin / cleared garden altar |
| J or left mouse | Attack; hold to repeat |
| Shift | Dash |
| Space | Moving slash after its first lifetime level-up |
| 1 / 2 / 3 | Pick a level-up card |
| Tab | Toggle region overview |
| G | Open retreat confirmation; cancel keeps the current run |
| R | On results, return to preparation; ignored during a run |
| Esc | Close a camp station or pause/resume combat |

## Run

Open `project.godot` in Godot **4.6 stable** and press F5, or run:

```sh
godot --path .
```

A fresh clone needs one editor import (`godot --headless --editor --path . --quit`) before command-line scripts. The standard `macOS` and `Windows` export presets build the camp and both combat regions. `macOS Height Lab` and `Windows Height Lab` export the separate comparison scene.

## Verify

Run every `tests/verify_*.gd` script with `godot --headless --path . --script res://tests/<name>.gd`. `verify_meta_preparation.gd` checks save migration, spending, equipment, respec, supply and their live-run effects. `verify_meta_expansion.gd` checks regional offers, growth gates and the fourth-hit weapon. `verify_growth_expansion.gd` checks the added growth tracks in saved and live runs; `verify_hub_layout.gd` checks stable equipment selection at compact window size. `verify_behavior_mods.gd` checks the three behavior options in live combat. `verify_jungle_pass.gd` and `verify_jungle_warden.gd` check separated route encounters and boss attacks; `verify_terrain_coherence.gd` checks visible blockers, the colored-floor boundary, ramp approach and controls. `verify_card_diversity.gd` checks early and late choices plus cross-branch effects. `verify_travel_camp.gd` checks station interactions. `verify_1g.gd` checks live spawning, the boss, pause and all run endings. The older 1A–1F and height-lab scripts remain regression checks.

The preparation tabs spend one shared banked currency on a first-region moving-slash weapon, second-region 3/4-hit weapon, a wisp accessory, eight capped and refundable permanent growth tracks grouped as attack, defense and mobility, and one-use healing supplies. The added tracks shorten wisp fire intervals, reduce incoming damage, and increase normal movement speed. The moving-slash weapon refunds part of the move's cooldown when its empowered basic hit lands. The second weapon explodes at the third-hit gathering point on hit four. Bought gear provides its fixed move; each weapon and accessory has one swappable option slot. Repeat clears randomly grant an unowned option from that region's fixed pool. Options are permanent, free to swap, and shown by gear under behavior changes or numeric adjustments. Equipment choices and details scroll independently, keeping the choice list still while comparing gear. The behavior options currently add a wave after an empowered basic hit, one wisp shot after a fourth-hit impact, or a short wisp-to-basic-attack follow-up. Purchases and equipment use the v3 profile format, migrating older records on the next write. The prices and effects are trial values pending real-play economy review. The full five-minute difficulty curve, both bosses' feel and fairness, new 3/4-hit and moving-slash feel, XP pacing, safe spots and long-session performance require play review. Boss and camp models are visual blockouts. Windows device play is pending. Art and sound are temporary. The current terrain model permits one ground elevation for each XY location; overlapping walkable floors, free jumping, falling and moving platforms are outside this stage.

Save compatibility is forward only after the v3 profile format introduced in v10: older builds may reject a profile after the new build saves it. Continue play with v10 or later after equipping options.

See `DEV_STATUS.md` for the current work and `LOOP_CONQUEST_MASTER.md` for the design rules. The next production sequence and its completion criteria are in [`docs/PRODUCTION_NEXT.md`](docs/PRODUCTION_NEXT.md). This planning update does not change the v25 game build. Check the latest working branch: `main` was still at the older 1G build when this plan was written.

## Audit follow-up v17

The player flashes on damage and visibly fades during hurt immunity. A health bar and a low-health label at 25% complement the HP number. Esc shows selected cards and their ranks; a compact running summary excludes the initial dash upgrade. G and the pause menu request retreat confirmation. Success and defeat settle immediately and freeze combat, then show results after a 0.8-second finish animation without changing time scale. Save errors offer a folder button while preserving the files. Enemy role definitions keep XP and currency independent of HP tuning.

The 2/4/6 lifetime card unlock milestones remain introductory progression; dash input remains immediate without buffering. GitHub Actions runs every `tests/verify_*.gd` script on Godot 4.6 stable. See `CHANGELOG.md` for past implementation records.

## v18 playtest

Each level immediately opens one card choice and heals 20% maximum HP. Each card has one reroll. Overflow XP queues choices in the same paused window. Permanent move unlocks apply at level-up; selection does not heal again.

The five-minute run now alternates short charge/ranged/support pressure with recovery periods, preserving the planned count relative to the v25 density trial. A new moving-slash card advances wisp fire by 0.12/0.24 seconds once per slash. In camp, four total attack growth ranks unlock a 60-currency choice of direct damage or wisp damage (+10 percentage points). Full respec refunds that cost too. The temple repeat-clear option pool includes EMBER_STEP for the wisp accessory: wisp hits advance dash recharge by 0.05 seconds, at most once per 0.3 seconds. These are trial values.

The current profile writes version 6 and reads versions 1–5 in the same save directory. Older executables cannot read version 6.

## v19 representative section

Introduced in the temple, and also used at the jungle gate since v22: freely leave/reenter the duel court while preserving boss HP; neither side attacks across the boundary. One retry prompt restores player/boss health and keeps the build, without restoring spent supplies. Ordinary deaths and a second boss death settle defeat.

A hidden garden off the gallery has a subtle western entrance leading to a separate 3000×2000 mini field, with a bent approach, paths around a pond, and an inner altar. Walk through its western exit to resume the same run. The main clock continues; inactive-field enemies and guardian damage persist across transitions. It is absent from the map until discovered. Defeat three strengthened guardians in separate parts of the field, then press E at the altar. First reward permanently awakens the equipped ember accessory (+20 percentage points projectile damage, +1 chain target, additive with cards); later clears heal 20% maximum HP once per run. Discovery/awakening are saved immediately. Profile v5 reads v1–v4 at the same save path; do not downgrade after saving with v19.

This is a playable blockout sample. Stage 2 economy acceptance, final art, Windows runtime and long-session GPU performance remain unverified.

## v20 boss trial

Temple: locked, longer-range charge and close pulse; late phase adds a separately warned second charge and an outside/inside pulse pair. Jungle: point-blank coverage on the sweep and a longer directional gust; late phase chains three separately warned attacks. Each completed pattern gives 1.2 seconds of stationary counter time (1.45 late phase), signaled by posture and color. Boss HP/damage are unchanged. Jungle uses the temple's size 9 / roughly 35-degree camera for comparison.

The target is 30–60 seconds with an ordinary build, faster with a strong build; this is not yet a measured human acceptance result. v22 writes profile v6.
