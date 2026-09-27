# Loop Conquest — Traveling Camp & Jungle Pass v09

Godot 4.6 combat and terrain prototype. The default scene is `game/travel_camp.tscn`: walk between the region map, equipment/growth, and departure stations, then press E to open the corresponding preparation tab. Region 1 remains `game/hybrid_region.tscn`; a first clear opens `game/jungle_pass.tscn`, a cliff/jungle route climbing to a high gate. Movement, enemy routing and hit detection use 2D ground coordinates; terrain records supply height, walkability and line-of-sight boundaries for the 3D scene and minimap.

The waterside court is the detailed traversal test: lowland, raised court and upper terrace (heights 0/160/320), north/south/east ramps, six consecutive stepping stones, deep-water cuts and dry detours. Three later spaces now have distinct routes: the temple grounds split around a central ruin, the gallery has two lanes and a middle crossing, and the sanctuary loops around a closed altar. These three spaces are flat blockouts; their art and final geometry remain open. The minimap projects the entire region through the gameplay camera's axes, so its diamond and the white camera footprint follow the view on screen. The main combat camera is closer and slightly steeper than v08 (`size=9.0`, about 35° ground angle); Tab still shows the full map.

Each combat scene runs a five-minute round with denser timed spawning, up to 48 ordinary enemies at once. A warning precedes every visible spawn. At five minutes its boss appears near the player on reachable ground. Region 1's gate boss uses a charge, central shock, and phase-2 outer ring. The jungle gate guardian uses a lateral sweep and a pushing gust, with faster timing in phase 2. Killing the boss ends the run successfully; death and voluntary retreat also settle the run. The first lifetime level-up permanently opens Space moving slash and the third combo hit; the third permanently opens the fourth hit. Moving slash links after an attack, preserves the next combo step and briefly avoids damage at its start. Cards can widen the slash or shorten its cooldown. Level-up choices include a manual-attack card and a wisp card while either branch remains available; a third comes from the full pool. Two new cards make manual hits advance wisp fire and wisp hits advance moving slash cooldown. A level-up card shows the resulting value and can be rerolled once. The result screen shows earned, lost and banked currency: success keeps all earnings, defeat loses 50%, and retreat loses 20% (rounding losses up, while preserving at least one earned coin). These rates are playtest values. The prototype first-clear record is still named `RELIC_TEMPLE` internally for compatibility; a relic-based story is not decided. Permanent card and move unlocks currently use `user://loop_conquest_1d_unlocks_*.json`; the settlement profile uses `user://loop_conquest_profile_*.json` with a recoverable prior slot. The versioned app title keeps using the v03 user-data directory so existing saves remain available.

The third hit reaches 145 ground pixels before enemy body radius, then visibly pulls caught enemies toward a point in front of the player. Water and cliffs block both damage and the bright slash/warning displays; a separate airborne blade no longer implies range across deep water. The terrain data drives the visible geometry, collision and enemy routes. The jungle gate's blockers now rise above their walking surface, its columns share visible and collision records, and the lintel avoids coincident faces. Walking and moving slash receive a small inward guide at ramp mouths, while wall collisions still block travel.

The earlier 2D temple map remains at `game/temple_region.tscn` for comparison. The focused height lab remains at `game/hybrid_height.tscn` and uses a separate local card-unlock record. The original combat sandbox is `game/main.tscn`.

| Input | Action |
|---|---|
| WASD | Move in camp and combat |
| E | Open a nearby camp station |
| J or left mouse | Attack; hold to repeat |
| Shift | Dash |
| Space | Moving slash after its first lifetime level-up |
| 1 / 2 / 3 | Pick a level-up card |
| Tab | Toggle region overview |
| G | Retreat and bank the remaining currency after a 20% loss |
| R | During a run, retreat and open results; on results, return to preparation |
| Esc | Close a camp station or pause/resume combat |

## Run

Open `project.godot` in Godot **4.6 stable** and press F5, or run:

```sh
godot --path .
```

A fresh clone needs one editor import (`godot --headless --editor --path . --quit`) before command-line scripts. The standard `macOS` and `Windows` export presets build the camp and both combat regions. `macOS Height Lab` and `Windows Height Lab` export the separate comparison scene.

## Verify

Run every `tests/verify_*.gd` script with `godot --headless --path . --script res://tests/<name>.gd`. `verify_meta_preparation.gd` checks save migration, spending, equipment, respec, supply and their live-run effects. `verify_meta_expansion.gd` checks regional offers, growth gates and the new fourth-hit weapon. `verify_jungle_pass.gd` and `verify_jungle_warden.gd` check routes and boss attacks; `verify_terrain_coherence.gd` checks visible blockers, ramp approach and controls. `verify_card_diversity.gd` checks early and late choices plus cross-branch effects. `verify_travel_camp.gd` checks station interactions. `verify_1g.gd` checks live spawning, the boss, pause and all run endings. The older 1A–1F and height-lab scripts remain regression checks.

The preparation tabs spend one shared banked currency on a first-region moving-slash weapon, second-region 3/4-hit weapon, a wisp accessory, five capped and refundable permanent growth tracks, and one-use healing supplies. The moving-slash weapon refunds part of the move's cooldown when its empowered basic hit lands. The second weapon explodes at the third-hit gathering point on hit four. Each purchased item has one rolled minor option. A successful repeat clear proposes a region-specific weapon option; the player can keep the old one or replace it, and the offer remains saved if the weapon has not yet been bought. Purchases and equipment are saved in the existing two-slot profile, migrating old v1 saves to v2 on the next write. The prices and effects are trial values pending real-play economy review. The full five-minute difficulty curve, both bosses' feel and fairness, new 3/4-hit and moving-slash feel, XP pacing, safe spots and long-session performance require play review. Boss and camp models are visual blockouts. Windows device play is pending. Art and sound are temporary. The current terrain model permits one ground elevation for each XY location; overlapping walkable floors, free jumping, falling and moving platforms are outside this stage.

Save compatibility is forward only for new v08 gear and affixes: an older v07 executable may reject a profile after v08 writes one of those items. Use v08 for continued play after purchasing new gear.

See `DEV_STATUS.md` for the current work and `LOOP_CONQUEST_MASTER.md` for the design rules.
