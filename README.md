# Loop Conquest — 1B View Prototype

Godot 4.6 project for comparing three 2D view treatments over the same playable combat blockout. View 2, medium oblique, opens by default. The 1A combat sandbox remains available as `game/main.tscn`.

| Input | Action |
|---|---|
| 1 / 2 / 3 | High topdown / medium oblique / low oblique view |
| WASD | Move (8 directions) |
| J or left mouse button | Attack once; hold to repeat |
| Space | Dash in movement direction, or last movement direction |
| K | Cycle available combo hits: 2 → 3 → 4 → 2 (training preview) |
| Esc | Pause or manually resume |
| R | Reset the sandbox |

Each view keeps the same 2400 × 1400 playfield, nine column/ruin footprints, and six enemies. It changes camera zoom and lead, actor vertical shape, floor ornament depth, and prop height. Props sort by their ground position, block movement at their footprints, and fade when they would hide the player. These are 2D projection sketches, not a tilted 3D camera or final art. Compare whether the character, attacks, enemy crowd, and nearby obstacles remain readable; the final view is not selected yet.

The attack points in the movement direction, not at the cursor. Moving during an attack is allowed. The third hit quickly gathers enemies in a forward fan around one nearby point, with space between them so each remains visible. Enemies also keep their spacing while chasing. The fourth hit releases the former wide magic wave. The vertical slam has been removed. Leaving the game window pauses it; returning does not resume automatically.

The current 1A motion is a temporary feel test: the character sweeps magic with alternating hand gestures, reaches out to clutch and pull enemies together on the third hit, then releases a wide wave on the fourth. Hits use brief impact slowdown, local sparks, short enemy stagger, and restrained camera motion. Player damage adds a short recoil, a health bar change, a red edge cue, and 0.70 seconds of damage protection. Final character animation and art remain for the later art stage.

The sandbox starts with two combo hits. In the later 1D upgrade system, sequential `U_CHAIN` choices will unlock hits three and four for each run. K previews those hits here. Two tougher enemies have 80 HP each so you can test gathering multiple targets and hitting both with the fourth strike.

## Run from source

Open `project.godot` in Godot **4.6 stable**, then press F6/F5. Or run:

```sh
godot --path .
```

## Verify

```sh
godot --headless --path . --script res://tests/verify_1a.gd
godot --headless --path . --script res://tests/verify_1b.gd
```

The scripts check 1A combat behavior and the 1B default view, mode switching, shared layout, Y-sort configuration, obstacle collision, and near-foreground fade. Screen readability and combat feel require a person to test the running window.

## Scope

1B has no wisp, XP, skill picks, boss, time-based spawning, campaign, or permanent progression. The blockout is for choosing a view and scale; the temple map is built in 1F.
