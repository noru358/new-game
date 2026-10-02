# First-region v44 measurements

These are automated diagnostic samples, not human playtests or acceptance of fun/art.

## Normal-speed first-three-run journey

Source: `09bcf2f4b86713a0a9fcf63505b9a2f91cdd2093`; official Godot 4.6.3, Linux headless, time scale 1.0, seed250, 270-active-second bound per run. Existing `sample_fresh_economy.gd` was not changed. Fresh marked XDG storage; original user saves/apps were not used. Source hashes at start/end match in the raw JSON.

The driver uses actual input, offered cards with 1.5-second dwell per selection, result/camp UI, purchases and separate equip actions. No forced XP, money, health or victory.

| Run | Outcome | Active / wall seconds | Card interruptions | Earned / awarded |
|---|---|---:|---:|---:|
| 1 | Boss success | 254.18 / 296.66 | 27 | 462 / 512 |
| 2 | Boss success | 254.32 / 298.21 | 28 | 496 / 516 |
| 3 | Confirmed retreat at bound | 270.00 / 273.21 | 2 | 9 / 7 |

After run1 the driver bought VITALITY1 (20) and W_FLOW (35), then equipped W_FLOW separately. After run2 it bought/equipped A_EMBER (24). Purchases, departure effects and disk/camp reloads agreed. Final currency956 reflects the deliberately sparse purchase policy, not a user preference to hoard currency.

Run3 stopped accumulating kills after9 and traveled much less despite continued clock/input. Its position was not recorded, so neither a game navigation bug nor a controller failure is established. It must not be averaged into a representative earning rate. A synthetic third-run equipment/unlock repro with seed250 did not repeat the stall and died after about80seconds; this is not a matched replay or balance distribution.

Run1 selected27 upgrades; the chosen fixed1.5-second dwell consumed42.18 wall seconds. This supports investigating interruption frequency, not a claim that human play takes the same time.

## Interruption-schedule replay

`replay_choice_interruption_trace.gd` replays run1's observed active-time level-up timestamps. It does not replay damage, combat, movement or player decisions.

The default produced27 modal interruptions. Opt-in batching (first6 immediate, later2 points/window,18-active-second lone-point limit, boss-ready flush) produced17. Both earned/spent27 points with0 pending and require27 clicks. Wall-time savings and human preference were NOT measured. Separate contract tests preserve immediate level healing, unlocks and XP; pending card effects arrive later, so combat outcomes can still differ.

## Navigation diagnosis

A64-unit sampling audit of open30-radius floor found points unable to attach to the32-unit A* grid. Some points are outside useful routes; this is not proof that a player was trapped there.

Two independent focused failures were reproduced:
- Grid padding of20 beyond actor radius erased a100-wide corridor even though a60-diameter actor fits. Candidate margin4 retains physical radius and path safety; a50-wide corridor remains closed.
- Rect2 excludes its bottom/right boundary, whereas segment intersection includes it. Exact32-unit padded-edge contact incorrectly rejected outward escape on those two sides. Candidate inclusive tolerance0.001 treats all four sides consistently and still rejects inward crossing.

The original temple's sampled unattached points went2→0 (one still disconnected); jungle15→6 with10 disconnected; candidate circuit19→0 with0 disconnected. Do not claim whole-map navigation solved or that either defect caused the unlocated run3 stall.

A previous hybrid-height test assumed the second route waypoint must already be belowy1670. The candidate takes additional safe waypoints before going around the water. The assertion now checks every point/segment against physical clearance and verifies the lower dry detour, rather than assuming a particular waypoint index. Focused/full regression outcomes belong in DEV_STATUS after they finish.


## Three build behavior samples

Pinned source8353c91, the existing normal-speed `sample_build_comparison.gd`, three separate fresh XDG roots run in parallel. Each uses synthetic prior history and294 cumulative expenditure; these are not fresh-earned economic runs. Gather/movement use their tailored policies; companion uses the existing single-hit/reposition link policy. Same seed250,270-active-second bound; different controllers and card offerings prevent causal build-strength ranking.

- Gather reached the boss retry offer at250.23active seconds,341kills,27choices. The diagnostic deliberately stops at that offer, so this is neither settled defeat nor victory. Fourth hits75; movement-slash hits46.
- Movement succeeded at252.63active seconds,346kills,28choices. Fourth hits38; movement-slash hits174; empowered-basic refund events114. These counters show the intended action patterns are exercised under their different policies, not proof of human preference.
- Companion link policy died at60.73active seconds,46kills,6choices. It had no S_WISP_COUNT choice. Third/fourth hit counts2/0 reflect its deliberate single-hit retreat controller, so do not infer that the companion branch itself is weak. The bounded common-controller follow-up reached the boss retry offer at252.77active seconds,344kills/28choices; it did not settle a defeat or victory. Wisp hits700 versus50 in the short link-policy sample, and fourth hits31 versus0, show why the early failure cannot diagnose branch strength. Different resulting fights/cards still prevent a causal numerical ranking. No buff was applied based on that early failure.

Time scale1 and source hashes/fixture/input details are recorded in each raw JSON. Headless concurrent runs do not validate frame-rate performance or art.
