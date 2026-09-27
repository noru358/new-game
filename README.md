# Loop Conquest — 1G Complete Run v01

Godot 4.6 combat and terrain prototype. The default scene is `game/hybrid_region.tscn`, a 3840 × 2160 trial region shown by an orthographic 3D camera. Movement, enemy routing and hit detection use 2D ground coordinates; terrain records supply height, walkability and line-of-sight boundaries for the 3D scene and minimap.

The waterside court is the detailed traversal test: lowland, raised court and upper terrace (heights 0/160/320), north/south/east ramps, six consecutive stepping stones, deep-water cuts and dry detours. Three later spaces now have distinct routes: the temple grounds split around a central ruin, the gallery has two lanes and a middle crossing, and the sanctuary loops around a closed altar. These three spaces are flat blockouts; their art and final geometry remain open. The minimap projects the entire region through the gameplay camera's axes, so its diamond and the white camera footprint follow the view on screen. The main combat camera is closer and slightly steeper than v08 (`size=9.0`, about 35° ground angle); Tab still shows the full map.

The main scene now runs a six-minute round: five enemy roles join at rising timed rates, up to 48 ordinary enemies at once. A warning precedes every visible spawn. At six minutes the gate boss appears near the player on reachable ground. It alternates a warned straight charge and a warned circular shock; killing it ends the run successfully. Death and voluntary retreat also end the run. Boss appearance is time-based, independent of which room the player visits. The original two-hit starting combo, two dash charges, automatic XP, level-up cards, `U_CHAIN`, wisps and seal remain. A result screen banks earned currency on all three endings and grants success and first-clear rewards only on success. The first temple relic is recorded for the later meta stage. Permanent card unlocks still use `user://loop_conquest_1d_unlocks_*.json`; the small stage-one settlement profile uses `user://loop_conquest_profile_*.json` with a recoverable prior slot.

The third hit reaches 145 ground pixels before enemy body radius, then visibly pulls caught enemies toward a point in front of the player. Water and cliffs block both damage and the bright slash/warning displays; a separate airborne blade no longer implies range across deep water. The terrain data drives the visible geometry, collision and enemy routes.

The earlier 2D temple map remains at `game/temple_region.tscn` for comparison. The focused height lab remains at `game/hybrid_height.tscn` and uses a separate local card-unlock record. The original combat sandbox is `game/main.tscn`.

| Input | Action |
|---|---|
| WASD | Move |
| J or left mouse | Attack; hold to repeat |
| Space | Dash |
| 1 / 2 / 3 | Pick a level-up card |
| Tab | Toggle region overview |
| G | Retreat and bank earned currency |
| R | During a run, bank currency and open results; on results, start a fresh run |
| Esc | Pause or resume |

## Run

Open `project.godot` in Godot **4.6 stable** and press F5, or run:

```sh
godot --path .
```

A fresh clone needs one editor import (`godot --headless --editor --path . --quit`) before command-line scripts. The standard `macOS` and `Windows` export presets build the default hybrid region. `macOS Height Lab` and `Windows Height Lab` export the separate comparison scene.

## Verify

Run every `tests/verify_*.gd` script with `godot --headless --path . --script res://tests/<name>.gd`. `verify_1g.gd` checks live spawning, the boss, pause and all run endings. `verify_run_profile.gd` checks one-time settlement and backup recovery. `verify_hybrid_region.gd` still checks the full map, combat edges, enemy routes and traversal by enabling its dedicated practice mode. The older 1A–1F and height-lab scripts remain regression checks.

The full six-minute difficulty curve, boss feel, XP pacing, safe spots and long-session performance still require play review. Windows device play is pending. Art and sound are temporary. The current terrain model permits one ground elevation for each XY location; overlapping walkable floors, free jumping, falling and moving platforms are outside this stage. A hub, permanent tree and a second outpost belong to stage two.

See `DEV_STATUS.md` for the current work and `LOOP_CONQUEST_MASTER.md` for the design rules.
