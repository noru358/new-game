# Loop Conquest — 1F Temple Region Prototype

The separate **Hybrid Height v04** comparison scene uses the existing 2D combat and navigation simulation with a 3D orthographic presentation. Run `godot --path . res://game/hybrid_height.tscn`, or export with `macOS Height Lab` / `Windows Height Lab`. The normal launch scene remains the previous temple prototype. The lab has three elevations, four ramps, six connected stepping stones and the accepted eight-enemy, five-role mix. It starts with the baseline two-hit combo and two dash charges; the 2/3/4-hit buttons switch combo length for comparison. XP/card progression remains in the previous temple prototype. Landmark buttons jump to each approach and the stepping stones; Tab toggles an overview, N respawns enemies, and R resets the scene. Esc resumes after focus loss. The omitted systems and proposed order are tracked in `HYBRID_REINTEGRATION_CHECKLIST.md`.

`HybridTerrain` is the common source for ground heights, the six stepping stones, 3D surfaces and 2D cliff barriers. Gameplay coordinates represent the ground plane; render positions add sampled elevation. Cliff barriers block melee and wisp shots, while connected paths permit combat. The airborne attack guide shows effective reach including enemy collision radius and stops at a blocking cliff. Terrain depth now hides the part of a slash behind a wall. Actor positions, camera follow and slash progress are interpolated for each rendered frame, while hit detection remains in the 2D physics tick. Enemy charge and shot warnings, bolts and area warnings use depth-tested 3D visuals; a zone cannot damage through a cliff. Sprite feet and ground shadows follow the sampled surface; the larger hybrid collision clearance keeps bodies outside cliff faces, and the wisp stays on the player's side. Projectile presentation follows the ground with a fixed offset in this comparison, without ballistic flight. Screen-space feel and art remain subject to play review. Overlapping walkable floors are outside this prototype.

Godot 4.6 combat prototype with XP, level-up cards, wisp upgrades, and five enemy roles. The selected **medium 2:1 diamond** view is fixed. The current scene is the 3840 × 2160 temple region with a minimap, diagonal architectural terrain, and four named spaces. The original 1A combat sandbox remains available as `game/main.tscn` for regression checks.

| Input | Action |
|---|---|
| 1 / 2 / 3 | Choose a card while the level-up screen is open |
| WASD | Move (8 directions) |
| J or left mouse button | Attack once; hold to repeat |
| Space | Dash in movement direction, or last movement direction |
| N | Refill the same eight practice enemies after clearing them; keep current XP and upgrades |
| Esc | Pause or manually resume |
| R | Reset the sandbox |

The current temple region is 3840 × 2160 with four named spaces, eleven columns, six water segments, nine low wall segments, and eight enemies. It uses the chosen 2:1 diamond ground and prop tops, camera zoom 1.25, and ground-position Y-sort. Large built structures follow the diamond axes; natural boundaries may vary. The minimap shows the region, visible camera area, player, and living enemies. These are 2D projection sketches and a blockout, not final art or a final map size. The earlier 2400 × 1400 practice field remains in `game/view_prototype.tscn`.

The starting waterside court is the first structured area: a central combat court, two openings through the canals, and a diamond stair to a raised temple terrace. The court is level with its surrounding ground; only the terrace reads as raised. Its perimeter blocks walking and dashing except through the stair. Dark water blocks movement. Extra gate pillars, landing shapes, and shallow-water patches were removed after they obscured the structure. The minimap uses one neutral ground color because its previous three vertical color bands were arbitrary map-coordinate ranges. The other three named areas remain rough blockouts pending review of this first court.

The attack points in the movement direction, not at the cursor. Moving during an attack also steers the current swing. The third hit follows direction changes until it catches enemies, then keeps its pull point fixed so gathered enemies stay together. A brief input buffer accepts a late press for the next swing but drops an early released press instead of launching a stale attack. If the player moves toward the gathering point during the pull, the destination advances just enough to preserve contact distance. Gathered enemies cannot deal contact damage during the brief pull and follow-up window; ordinary contact resumes afterward. Enemies also keep their spacing while chasing. The fourth hit releases the former wide magic wave. The vertical slam has been removed. Leaving the game window pauses it; returning does not resume automatically.

The current 1A motion is a temporary feel test: the character sweeps magic with alternating hand gestures, reaches out to clutch and pull enemies together on the third hit, then releases a wide wave on the fourth. Hits use brief impact slowdown, local sparks, short enemy stagger, and restrained camera motion. Player damage adds a short recoil, a health bar change, a red edge cue, and 0.70 seconds of damage protection. Final character animation and art remain for the later art stage.

Each run starts with two combo hits. Choose `U_CHAIN` once to unlock hit three and again for hit four. The card stays in the level-up offers until both are available. K no longer previews later hits in this scene. The eight-enemy practice wave mixes chasing fragments, one telegraphed charging beast, two lanterns that fire straight projectiles, one area caster, and one support enemy. Charge and shot lines lock their direction, so movement or a dash can evade them. Lanterns route around ruins to find a clear shot; hostile projectiles stop at ruins.

The baseline wisp follows the player and fires a magic projectile at the nearest visible enemy within 520 px when a ruin does not block the path. It fires every 1.25 seconds and deals 10 damage at the current base attack value. Multiple wisps prefer different enemies when an in-flight projectile already covers a kill. The wisp acts independently of the manual combo. It waits if no valid target is available, and its cooldown pauses with the game. The projectile gently adjusts toward a moving target for its first 0.42 seconds, while ruins still block it. The wisp can aim at the exposed edge of an enemy whose center is hidden by a ruin. A small bright blue flame marks the launch, projectile trail, and impact. The temporary HUD line shows its cooldown.

Defeated enemies drop XP orbs. The pickup pull now starts within 260 px. Collecting them fills a level meter (`8 + 2 × (level − 1)` XP for the next level); ordinary enemies give 2 XP and tougher enemies give 4 XP. Each level pauses combat for up to three card choices and restores 20% maximum health after a choice. The current pool has 11 card types: manual damage/speed/reach/combo, wisp damage/cadence/count/orbit/chain, an auxiliary auto seal, and dash recharge. `U_STEP` rank 1 cuts recharge by 15%, rank 2 raises capacity to two dashes, and rank 3 cuts recharge by 30% total. The HUD shows ready charges and the next recharge. Wisp count supports up to three. Orbit contact damage adds to the projectile attack. The chain card links a hit to nearby enemies. The selected upgrades reset on R or a new run.

All orbiting wisps now use one clock shared through the player. A wisp added later joins its assigned position around the circle instead of drifting into an existing wisp. The current effect shapes are still topdown sketches. A later visual pass will adapt the attack arcs, impact rings, and telegraphs to the selected 2:1 diamond view without changing their gameplay hitboxes.

Count, orbit, and chain cards permanently enter the offer pool after **2, 4, and 6 cumulative level-ups across runs**. The total is saved in two alternating `user://loop_conquest_1d_unlocks_*.json` files; the upgrade effects themselves still reset each run. The HUD shows the next unlock. These early thresholds are for the prototype and can be tuned after play. The record is local to each device and does not sync between macOS and Windows. After clearing eight enemies, press N to repeat their placement and keep collecting XP. This is a practice loop, not the later timed spawn system.

Wisp power ranks add 0.20 damage coefficient each to the new 1.0 base (up to 1.60), with a stronger local hit flash, short enemy recoil, and a distinct hit sound. Orbit damage is 4/7 per rank, and chain jumps retain 68% of the previous hit's damage. Enemies route around columns, water, and walls when direct pursuit is blocked.

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
godot --headless --path . --script res://tests/verify_1d_contact_ai.gd
godot --headless --path . --script res://tests/verify_1e.gd
godot --headless --path . --script res://tests/verify_1f.gd
godot --headless --path . --script res://tests/verify_hybrid_height.gd
godot --headless --path . --script res://tests/verify_hybrid_feedback.gd
godot --headless --path . --script res://tests/verify_hybrid_corner_ai.gd
godot --headless --path . --script res://tests/verify_hybrid_roles.gd
```

The scripts check 1A combat behavior, the fixed 1B view and space layout, 1C wisp behavior, 1D growth and obstacle targeting, 1E mixed enemy roles, and 1F terrain, minimap, routes, and repeat wave. Screen readability, upgrade pacing, and combat feel require a person to test the running window.

## Scope

1F has no boss, time-based spawning, campaign, or full meta progression. Only the lifetime card-unlock counter persists between runs. The region blockout tests map scale, traversal, enemy routing, and screen readability. Current sound effects are temporary combat feedback and will be replaced during the later audio and visual pass.
