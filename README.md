# Loop Conquest — 1F Hybrid Region v08

Godot 4.6 combat and terrain prototype. The default scene is `game/hybrid_region.tscn`, a 3840 × 2160 trial region shown by an orthographic 3D camera. Movement, enemy routing and hit detection use 2D ground coordinates; terrain records supply height, walkability and line-of-sight boundaries for the 3D scene and minimap.

The waterside court is the detailed traversal test: lowland, raised court and upper terrace (heights 0/160/320), north/south/east ramps, six consecutive stepping stones, deep-water cuts and dry detours. The temple grounds, corridor and sanctuary share the same simulation and camera but remain flat blockouts with a few floors, water patches and low walls. Their layout and elevation are not final. The minimap projects the entire region through the gameplay camera's axes, so its diamond and the white camera footprint follow the view on screen.

The main scene has the accepted eight enemies in five roles, the two-hit starting combo, two dash charges, automatic XP on defeat, level-up cards, three/four-hit unlocks through `U_CHAIN`, and wisp and seal upgrades. Defeat eight enemies and press N to repeat their placement while retaining the current run's XP and cards. Permanent cumulative card unlocks use the existing `user://loop_conquest_1d_unlocks_*.json` files. This is still a practice loop; timed spawning, boss and run completion belong to 1G.

The earlier 2D temple map remains at `game/temple_region.tscn` for comparison. The focused height lab remains at `game/hybrid_height.tscn` and uses a separate local card-unlock record. The original combat sandbox is `game/main.tscn`.

| Input | Action |
|---|---|
| WASD | Move |
| J or left mouse | Attack; hold to repeat |
| Space | Dash |
| 1 / 2 / 3 | Pick a level-up card |
| Tab | Toggle region overview |
| Top buttons | Jump to a named test landmark |
| N | Replace practice enemies and keep run growth |
| R | Start a new run |
| Esc | Pause or resume |

## Run

Open `project.godot` in Godot **4.6 stable** and press F5, or run:

```sh
godot --path .
```

A fresh clone needs one editor import (`godot --headless --editor --path . --quit`) before command-line scripts. The standard `macOS` and `Windows` export presets build the default hybrid region. `macOS Height Lab` and `Windows Height Lab` export the separate comparison scene.

## Verify

Run every `tests/verify_*.gd` script with `godot --headless --path . --script res://tests/<name>.gd`. In particular, `verify_hybrid_region.gd` checks the full map, enemy routes, water blocking, the camera-aligned minimap and walking across the court, terrace and east link. The older 1A–1F and height-lab scripts remain regression checks.

Visual readability, combat feel, XP pacing and long-session performance still require play review. Windows export format is checked here; Windows device play is pending. Screen art and sound are temporary. The current terrain model permits one ground elevation for each XY location; overlapping walkable floors, free jumping, falling and moving platforms are outside this stage.

See `DEV_STATUS.md` for the current work and `LOOP_CONQUEST_MASTER.md` for the design rules.
