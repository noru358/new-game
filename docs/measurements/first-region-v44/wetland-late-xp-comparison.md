# 後半 XP 比較 / 2026-10-03

Runtime game files match baa68b5. Same grown249-investment fixture, seed250, normal speed, route/card preference,270active-second bound; only existing late_xp_slope_trial was enabled after initial setup. The first six choices and immediate selection policy remain unchanged. This is not enabled in the v45 app.

At240seconds baseline→candidate:26→21 choices,40.778→32.957seconds synthetic card dwell,322→320kills,452→441 earned currency,110→110HP. Baseline eventually succeeded at251.97active seconds with2HP; candidate ended with the boss retry offer. Different damage/card opportunities and timing do not isolate a human difficulty judgment. Do not report wall-time differences as a pure XP saving because executor processing time also differed.

The source/copy hash guard passed. Raw candidate data: wetland-late-xp-grown.json; baseline:wetland-normal-speed-grown.json. Reproducer:tests/sample_wetland_late_xp.gd with scripts/launch_flow_sample.py. Keep the default unchanged pending broader play judgment; do not tune until this controller wins.
