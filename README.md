# Loop Conquest — 1G Combat Feedback v05

Godot 4.6 combat and terrain prototype. The default scene is `game/hybrid_region.tscn`, a 3840 × 2160 trial region shown by an orthographic 3D camera. Movement, enemy routing and hit detection use 2D ground coordinates; terrain records supply height, walkability and line-of-sight boundaries for the 3D scene and minimap.

The waterside court is the detailed traversal test: lowland, raised court and upper terrace (heights 0/160/320), north/south/east ramps, six consecutive stepping stones, deep-water cuts and dry detours. Three later spaces now have distinct routes: the temple grounds split around a central ruin, the gallery has two lanes and a middle crossing, and the sanctuary loops around a closed altar. These three spaces are flat blockouts; their art and final geometry remain open. The minimap projects the entire region through the gameplay camera's axes, so its diamond and the white camera footprint follow the view on screen. The main combat camera is closer and slightly steeper than v08 (`size=9.0`, about 35° ground angle); Tab still shows the full map.

The main scene now runs a five-minute round with denser timed spawning, up to 48 ordinary enemies at once. A warning precedes every visible spawn. At five minutes the gate boss appears near the player on reachable ground. It alternates a warned straight charge and a warned circular shock; killing it ends the run successfully. Death and voluntary retreat also end the run. Boss appearance is time-based, independent of which room the player visits. The first lifetime level-up permanently opens Q moving slash and the third combo hit; the third permanently opens the fourth hit. Q links after an attack, preserves the next combo step and briefly avoids damage at its start. Cards can widen Q or shorten its cooldown. A level-up card shows the resulting value and can be rerolled once. The result screen shows earned, lost and banked currency: success keeps all earnings, defeat loses 50%, and retreat loses 20% (rounding losses up, while preserving at least one earned coin). These rates are playtest values. The prototype first-clear record is still named `RELIC_TEMPLE` internally; a relic-based story is not decided. Permanent card and move unlocks currently use `user://loop_conquest_1d_unlocks_*.json`; the small settlement profile uses `user://loop_conquest_profile_*.json` with a recoverable prior slot. The versioned app title keeps using the v03 user-data directory so existing saves remain available.

The third hit reaches 145 ground pixels before enemy body radius, then visibly pulls caught enemies toward a point in front of the player. Water and cliffs block both damage and the bright slash/warning displays; a separate airborne blade no longer implies range across deep water. The terrain data drives the visible geometry, collision and enemy routes.

The earlier 2D temple map remains at `game/temple_region.tscn` for comparison. The focused height lab remains at `game/hybrid_height.tscn` and uses a separate local card-unlock record. The original combat sandbox is `game/main.tscn`.

| Input | Action |
|---|---|
| WASD | Move |
| J or left mouse | Attack; hold to repeat |
| Space | Dash |
| Q | Moving slash after its first lifetime level-up |
| 1 / 2 / 3 | Pick a level-up card |
| Tab | Toggle region overview |
| G | Retreat and bank the remaining currency after a 20% loss |
| R | During a run, retreat and open results; on results, start a fresh run |
| Esc | Pause or resume |

## Run

Open `project.godot` in Godot **4.6 stable** and press F5, or run:

```sh
godot --path .
```

A fresh clone needs one editor import (`godot --headless --editor --path . --quit`) before command-line scripts. The standard `macOS` and `Windows` export presets build the default hybrid region. `macOS Height Lab` and `Windows Height Lab` export the separate comparison scene.

## Verify

Run every `tests/verify_*.gd` script with `godot --headless --path . --script res://tests/<name>.gd`. `verify_1g.gd` checks live spawning, the boss, pause and all run endings. `verify_run_profile.gd` checks one-time settlement and backup recovery. `verify_hybrid_region.gd` still checks the full map, combat edges, enemy routes and traversal by enabling its dedicated practice mode. The older 1A–1F and height-lab scripts remain regression checks.

The full five-minute difficulty curve, new 3/4-hit and Q feel, XP pacing, safe spots and long-session performance require play review. Windows device play is pending. Art and sound are temporary. The current terrain model permits one ground elevation for each XY location; overlapping walkable floors, free jumping, falling and moving platforms are outside this stage. A first hub UI, equipment, purchases and another playable region are later work.

See `DEV_STATUS.md` for the current work and `LOOP_CONQUEST_MASTER.md` for the design rules.
