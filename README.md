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

The attack points in the movement direction, not at the cursor. Moving during an attack is allowed. The third hit is wider and stronger. The fourth hit drops magic vertically onto a fixed point in front of the character. Leaving the game window pauses it; returning does not resume automatically.

The current 1A motion is a temporary feel test: the character sweeps magic with alternating hand gestures, releases a wider third hit, then brings both hands down for the fourth strike. Hits use brief impact slowdown, local sparks, short enemy stagger, and restrained camera motion. Player damage adds a short recoil, a health bar change, a red edge cue, and 0.70 seconds of damage protection. Final character animation and art remain for the later art stage.

The run starts with two combo hits. In the later 1C upgrade system, sequential `U_CHAIN` choices will unlock hits three and four for that run. K only previews those hits in the 1A sandbox. The tougher enemy has 80 HP so you can land a full combo.

## Run from source

Open `project.godot` in Godot **4.6 stable**, then press F6/F5. Or run:

```sh
godot --path .
```

## Verify

```sh
godot --headless --path . --script res://tests/verify_1a.gd
```

The verification script checks movement, dash distance and cooldown, 0.70 second hit protection, one-hit-per-press, held 2/3/4-hit combos, the fourth-hit strike area, and pause. Gameplay feel and focus switching require a person to test the running window.

## Scope

1A has no wisp, XP, skill picks, boss, time-based spawning, campaign, or permanent progression. The flat grid is a temporary training arena, not the stage 1E temple map.
