# Loop Conquest — 1C Wisp Prototype

Godot 4.6 combat prototype with one automatic wisp companion. The selected view is **2, medium 2:1 diamond**, and opens by default. The other views and G grid toggle remain for comparison. The 1A combat sandbox remains available as `game/main.tscn`.

| Input | Action |
|---|---|
| 1 / 2 / 3 | High topdown / medium / low camera view |
| G | Switch square and 2:1 diamond ground in views 2 and 3 |
| WASD | Move (8 directions) |
| J or left mouse button | Attack once; hold to repeat |
| Space | Dash in movement direction, or last movement direction |
| K | Cycle available combo hits: 2 → 3 → 4 → 2 (training preview) |
| Esc | Pause or manually resume |
| R | Reset the sandbox |

Each view keeps the same 2400 × 1400 playfield, nine column/ruin footprints, and six enemies. It changes camera zoom and lead, actor vertical shape, and prop height. Views 2 and 3 start with a real 2:1 diamond ground lattice and matching diamond prop tops; G restores the square ground lattice at the same camera scale for direct comparison. Props sort by their ground position, block movement at their footprints, and fade when they would hide the player. These are 2D projection sketches, not a tilted 3D camera or final art. View 2 with diamond ground is the camera and projection baseline for subsequent stages; final character and environment art remain open.

The attack points in the movement direction, not at the cursor. Moving during an attack is allowed. The third hit quickly gathers enemies in a forward fan around one nearby point, with space between them so each remains visible. Enemies also keep their spacing while chasing. The fourth hit releases the former wide magic wave. The vertical slam has been removed. Leaving the game window pauses it; returning does not resume automatically.

The current 1A motion is a temporary feel test: the character sweeps magic with alternating hand gestures, reaches out to clutch and pull enemies together on the third hit, then releases a wide wave on the fourth. Hits use brief impact slowdown, local sparks, short enemy stagger, and restrained camera motion. Player damage adds a short recoil, a health bar change, a red edge cue, and 0.70 seconds of damage protection. Final character animation and art remain for the later art stage.

The sandbox starts with two combo hits. In the later 1D upgrade system, sequential `U_CHAIN` choices will unlock hits three and four for each run. K previews those hits here. Two tougher enemies have 80 HP each so you can test gathering multiple targets and hitting both with the fourth strike.

The baseline wisp follows the player and fires a magic projectile at the nearest visible enemy within 520 px when a ruin does not block the path. After play feedback it fires every 1.6 seconds, deals 6.5 damage at the current base attack value, and acts independently of the manual combo. It waits if no valid target is available, and its cooldown pauses with the game. A small bright blue flame marks the launch, projectile trail, and impact. The temporary HUD line shows its cooldown.

Future wisp upgrades include more wisps, orbiting contact damage, fire rate, damage, and attack pattern. The orbiting contact damage will add to the current projectile attack. These cards will unlock after conditions are met and must then be chosen again through level-up in each run. No upgrade or unlock is implemented in 1C; their exact rules belong to 1D.

At a fully upgraded build, the manual attack and wisp should feel similarly present in combat. This is a feel target rather than an exact 50:50 damage split; it needs to be checked with the 1D upgrade system in play.

## Run from source

Open `project.godot` in Godot **4.6 stable**, then press F6/F5. Or run:

```sh
godot --path .
```

## Verify

```sh
godot --headless --path . --script res://tests/verify_1a.gd
godot --headless --path . --script res://tests/verify_1b.gd
godot --headless --path . --script res://tests/verify_1c.gd
```

The scripts check 1A combat behavior, the 1B view and space layout, and 1C wisp target selection, damage, projectile blocking, pause, and manual-combo independence. Screen readability and combat feel require a person to test the running window.

## Scope

1C has no XP, skill picks, boss, time-based spawning, campaign, or permanent progression. The blockout is for testing combat; the temple map is built in 1F.
