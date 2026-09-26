# Loop Conquest — 1D Play Feedback Prototype

Godot 4.6 combat prototype with XP, level-up cards, and wisp upgrades. The selected view is **2, medium 2:1 diamond**, and opens by default. The other views and G grid toggle remain for comparison. The original 1A combat sandbox remains available as `game/main.tscn`.

| Input | Action |
|---|---|
| 1 / 2 / 3 | High topdown / medium / low view; choose a card while the level-up screen is open |
| G | Switch square and 2:1 diamond ground in views 2 and 3 |
| WASD | Move (8 directions) |
| J or left mouse button | Attack once; hold to repeat |
| Space | Dash in movement direction, or last movement direction |
| N | Refill the same six practice enemies after clearing them; keep current XP and upgrades |
| Esc | Pause or manually resume |
| R | Reset the sandbox |

Each view keeps the same 2400 × 1400 playfield, nine column/ruin footprints, and six enemies. It changes camera zoom and lead, actor vertical shape, and prop height. Views 2 and 3 start with a real 2:1 diamond ground lattice and matching diamond prop tops; G restores the square ground lattice at the same camera scale for direct comparison. Props sort by their ground position, block movement at their footprints, and fade when they would hide the player. These are 2D projection sketches, not a tilted 3D camera or final art. View 2 with diamond ground is the camera and projection baseline for subsequent stages; final character and environment art remain open.

The attack points in the movement direction, not at the cursor. Moving during an attack also steers the current swing. The third hit follows direction changes until it catches enemies, then keeps its pull point fixed so gathered enemies stay together. A brief input buffer accepts a late press for the next swing but drops an early released press instead of launching a stale attack. If the player moves toward the gathering point during the pull, the destination advances just enough to preserve contact distance. Gathered enemies cannot deal contact damage during the brief pull and follow-up window; ordinary contact resumes afterward. Enemies also keep their spacing while chasing. The fourth hit releases the former wide magic wave. The vertical slam has been removed. Leaving the game window pauses it; returning does not resume automatically.

The current 1A motion is a temporary feel test: the character sweeps magic with alternating hand gestures, reaches out to clutch and pull enemies together on the third hit, then releases a wide wave on the fourth. Hits use brief impact slowdown, local sparks, short enemy stagger, and restrained camera motion. Player damage adds a short recoil, a health bar change, a red edge cue, and 0.70 seconds of damage protection. Final character animation and art remain for the later art stage.

Each run starts with two combo hits. Choose `U_CHAIN` once to unlock hit three and again for hit four. The card stays in the level-up offers until both are available. K no longer previews later hits in this scene. Two tougher enemies have 80 HP each so you can test gathering multiple targets and hitting both with the fourth strike.

The baseline wisp follows the player and fires a magic projectile at the nearest visible enemy within 520 px when a ruin does not block the path. In this 1D feedback build, it fires every 1.25 seconds and deals 10 damage at the current base attack value. Multiple wisps prefer different enemies when an in-flight projectile already covers a kill. The wisp acts independently of the manual combo. It waits if no valid target is available, and its cooldown pauses with the game. The projectile gently adjusts toward a moving target for its first 0.42 seconds, while ruins still block it. The wisp can aim at the exposed edge of an enemy whose center is hidden by a ruin. A small bright blue flame marks the launch, projectile trail, and impact. The temporary HUD line shows its cooldown.

Defeated enemies drop XP orbs. The pickup pull now starts within 260 px. Collecting them fills a level meter (`8 + 2 × (level − 1)` XP for the next level); ordinary enemies give 2 XP and tougher enemies give 4 XP. Each level pauses combat for up to three card choices and restores 20% maximum health after a choice. The current pool has 11 card types: manual damage/speed/reach/combo, wisp damage/cadence/count/orbit/chain, an auxiliary auto seal, and dash recharge. `U_STEP` rank 1 cuts recharge by 15%, rank 2 raises capacity to two dashes, and rank 3 cuts recharge by 30% total. The HUD shows ready charges and the next recharge. Wisp count supports up to three. Orbit contact damage adds to the projectile attack. The chain card links a hit to nearby enemies. The selected upgrades reset on R or a new run.

All orbiting wisps now use one clock shared through the player. A wisp added later joins its assigned position around the circle instead of drifting into an existing wisp. The current effect shapes are still topdown sketches. A later visual pass will adapt the attack arcs, impact rings, and telegraphs to the selected 2:1 diamond view without changing their gameplay hitboxes.

Count, orbit, and chain cards permanently enter the offer pool after **2, 4, and 6 cumulative level-ups across runs**. The total is saved in two alternating `user://loop_conquest_1d_unlocks_*.json` files; the upgrade effects themselves still reset each run. The HUD shows the next unlock. These early thresholds are for the prototype and can be tuned after play. The record is local to each device and does not sync between macOS and Windows. After clearing six enemies, press N to repeat their placement and keep collecting XP. This is a practice loop, not the later timed spawn system.

Wisp power ranks add 0.20 damage coefficient each to the new 1.0 base (up to 1.60), with a stronger local hit flash, short enemy recoil, and a distinct hit sound. Orbit damage is 4/7 per rank, and chain jumps retain 68% of the previous hit's damage. The six practice enemies route around the nine ruin footprints when direct pursuit is blocked.

At a fully upgraded build, the manual attack and wisp should feel similarly present in combat. This is a feel target rather than an exact 50:50 damage split; it needs to be checked with the 1D upgrade system in play.

## Run from source

Open `project.godot` in Godot **4.6 stable**, then press F6/F5. Or run:

```sh
godot --path .
```

On a fresh clone, open the project once in the editor (or run `godot --headless --editor --path . --quit`) to import assets and register GDScript classes before running the command-line checks below.

## Verify

```sh
godot --headless --path . --script res://tests/verify_1a.gd
godot --headless --path . --script res://tests/verify_1b.gd
godot --headless --path . --script res://tests/verify_1c.gd
godot --headless --path . --script res://tests/verify_1d.gd
godot --headless --path . --script res://tests/verify_1d_feedback.gd
godot --headless --path . --script res://tests/verify_gather_safety.gd
godot --headless --path . --script res://tests/verify_1d_play_feedback.gd
```

The scripts check 1A combat behavior, the 1B view and space layout, 1C wisp behavior, and 1D XP, card choice, combo unlocks, wisp/seal upgrades, persistent card unlocks, practice wave reset, obstacle routing, partial visibility, and moving-target hits. Screen readability, upgrade pacing, and combat feel require a person to test the running window.

## Scope

1D has no new enemy roles, boss, time-based spawning, campaign, or full meta progression. Only the lifetime card-unlock counter persists between runs. The blockout is for testing combat and growth; the temple map is built in 1F.
