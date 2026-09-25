# Loop Conquest — 1A Feel Sandbox

Godot 4.6 project for testing movement, manual arcane melee, a two-hit base combo with previews of hits three and four, held attack repeat, dash, one pursuing enemy type, damage, camera follow, and focus pause. This is a feel test with four regular enemies and one tougher instance of the same type. Press **R** to reset it.

| Input | Action |
|---|---|
| WASD | Move (8 directions) |
| J or left mouse button | Attack once; hold to repeat |
| Space | Dash in movement direction, or last movement direction |
| K | Cycle available combo hits: 2 → 3 → 4 → 2 (training preview) |
| Esc | Pause or manually resume |
| R | Reset the sandbox |

The attack points in the movement direction, not at the cursor. Moving during an attack is allowed. The third hit quickly gathers enemies in a forward fan to one nearby point. The fourth hit releases the former wide magic wave. The vertical slam has been removed. Leaving the game window pauses it; returning does not resume automatically.

The current 1A motion is a temporary feel test: the character sweeps magic with alternating hand gestures, reaches out to clutch and pull enemies together on the third hit, then releases a wide wave on the fourth. Hits use brief impact slowdown, local sparks, short enemy stagger, and restrained camera motion. Player damage adds a short recoil, a health bar change, a red edge cue, and 0.70 seconds of damage protection. Final character animation and art remain for the later art stage.

The sandbox starts with two combo hits. In the later 1D upgrade system, sequential `U_CHAIN` choices will unlock hits three and four for each run. K only previews those hits in the 1A sandbox. Two tougher enemies have 80 HP each so you can test gathering multiple targets and hitting both with the fourth strike.

## Run from source

Open `project.godot` in Godot **4.6 stable**, then press F6/F5. Or run:

```sh
godot --path .
```

## Verify

```sh
godot --headless --path . --script res://tests/verify_1a.gd
```

The verification script checks movement, dash distance and cooldown, 0.70 second hit protection, one-hit-per-press, held 2/3/4-hit combos, the third-hit fan and multi-target gathering, the wide fourth hit, and pause. Gameplay feel and focus switching require a person to test the running window.

## Scope

1A has no wisp, XP, skill picks, boss, time-based spawning, campaign, or permanent progression. The flat grid and camera are temporary for combat testing; the viewpoint is explored in 1B and the temple map is built in 1F.
