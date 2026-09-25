# Loop Conquest — 1A Feel Sandbox

Godot 4.6 project for testing movement, manual arcane melee, a three-hit combo, held attack repeat, dash, one pursuing enemy type, damage, camera follow, and focus pause. This is a feel test with four fixed enemies. Press **R** to reset it.

| Input | Action |
|---|---|
| WASD | Move (8 directions) |
| J or left mouse button | Attack once; hold to repeat |
| Space | Dash in movement direction, or last movement direction |
| Esc | Pause or manually resume |
| R | Reset the sandbox |

The attack points in the movement direction, not at the cursor. Moving during an attack is allowed. The third hit is wider and stronger. Leaving the game window pauses it; returning does not resume automatically.

## Run from source

Open `project.godot` in Godot **4.6 stable**, then press F6/F5. Or run:

```sh
godot --path .
```

## Verify

```sh
godot --headless --path . --script res://tests/verify_1a.gd
```

The verification script checks movement, dash distance and cooldown, dash/hurt protection, one-hit-per-press, held combo, and pause. Gameplay feel and focus switching require a person to test the running window.

## Scope

1A has no wisp, XP, skill picks, boss, time-based spawning, campaign, or permanent progression. The flat grid is a temporary training arena, not the stage 1E temple map.
