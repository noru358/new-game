# Hidden integration v51 — three lanes mounted, final GUI/CI pending

Current source: `68ac49b03bb19b30059bb797ab61758505ed2b1a`; game mounting source `a9642b033f0a5304a45b27bdef639e3be250b1a6`. The difference is bounded capture fixtures only. This is a candidate, not a release or first-region completion.

- Base production `1aac501f097ff565f5fd249b9411ab91e64b3223`; canonical `686228f1d2f7cad0f09311c2006f46c6c16ce9d3` preserved, main not used.
- Flow final `aa3ff600f9ab5c9960d3c17f5d0ae504ed689041`: all9 linear commits.
- Temple final `d2abbffeda52966182b00257bb544a3cfcb5107b`: all4 linear commits.
- Jungle parent-pinned final `e06a2fa792945d7662bf29fe8546b3c519a089c6`: its1 full commit.

Flow owns roots, labels, discovery_marker and latch. Each art helper's build/build_entry is a child of the corresponding root. Jungle section water/stone/bush/moss loops are removed; helper owns original hidden2/main4 waterfall sheets. Altars, embers, rewards, guardians6, discovery IDs and portal coordinates remain. Structural fixtures require actual mounts, with no test-created fallback.

Import+13 affected fixtures passed at a9642b0; actual sanctuary7009 checks/1268rays/existing20/new0/cofacial1584→0. Actual water duplicate/moved/material mutations in isolated copies are detected. Local engine1 serial inventory114 fixtures:109 passed,5 failed under fixed60fps. Those same5 passed with unchanged game/expectations under default physics at68ac49b. Preserve the failures and policy distinction; this is not one-policy full PASS. Nested-engine future-save/settings fixtures2, dedicated depth and native UI remain for exact final Linux CI.

Previous exact-head CI0a4e505 run37126591308 completed115 fixtures:109PASS/6FAIL. Shared minimap caption direct region_id read failed on legacy hybrid_height scenes, even while game assertions passed. Minimal one-line optional get guard is78a2cd2; the6 affected fixtures plus mounting passed locally. Later depth/UI/price steps were skipped in that CI. Latest whole CI is still required.

Covered native windows can omit frame_post_draw. The fixed capture fixture now uses force_draw(false), at most4 image-read attempts, exact960/1280 PNG size checks and per-stage progress.json/console messages. Product focus behavior and user OS windows are unchanged. Parent's GUI slot is still pending; no combined PNGs yet. Planned24 views include both maps' actual normal-input entrance/return, near exit labels, overview art and legal reward/save approach. Temple guardian damage is synthetic; combat/time pressure frozen. Existing lane renders are not final combined evidence. Jungle final source's prior native26PNG/10points is incomplete; prior full84PNG uses older geometry.

Portable evidence lives in `evidence/hidden-combined-v51`: three-lane-source-manifest.json, three-lane-impact-summary.json, three-lane-serial-full-summary.json, default-physics-control-summary.json, legacy-minimap-guard-summary.json, waterfall-negative-controls.json, ci-0a4e505-failure.json, and per-fixture text logs. Task runner and working archives remain outside the repository in task10. DEV_STATUS/PRODUCTION_NEXT current sections reflect this checkpoint. MASTER unchanged.

Project/profile/growth/player and3 retained layouts are byte-identical to base. Approved jungle layout deltas are first passage width170→130,2 receiving pools, landmark backing footprints and hidden terrain install; independent assertions preserve portal4, wave6 and altar. Temple threshold height0.5 remains below shadow. Official Mac4.6stable engine SHA256974197a7e6663dba803ae97c3b2d987b77a37b6e70088400ecf0ccc591cbdfbc; copied engine, UUIDuserdata, one headless engine at a time. No user saves/apps/checkouts changed.

Remaining: parent GUI slot after temple art, bounded combined24 captures/reward/save/exit confirmation, then exact final-head whole Linux CI. No merge/release/package/app replacement. Temple exact altar-center cylinder/ember Body~34%, jungle waterfall/FX partial occlusion, human art/place/fun acceptance, natural complete runs and long-session performance remain unresolved.

---

The earlier two-lane checkpoint below is historical and does not describe the current three-lane mount.

# Hidden integration v51 — two completed lanes, jungle pending

This is an independent candidate, not a release or first-region completion.

- Repository: https://github.com/noru358/new-game (owner/repo, ADMIN permission and PR list verified).
- Base: `1aac501f097ff565f5fd249b9411ab91e64b3223` (`codex/first-region-production-v44`).
- Canonical: `686228f1d2f7cad0f09311c2006f46c6c16ce9d3`, verified ancestor of base. Never based on main.
- Flow: `aa3ff600f9ab5c9960d3c17f5d0ae504ed689041` (all nine linear commits after base, including input fixture `d589595`).
- Temple: `d2abbffeda52966182b00257bb544a3cfcb5107b` (all four linear commits after base).
- Jungle: no parent-pinned final SHA yet; not fetched or declared complete.

## Mounting

Flow owns `hidden_visual_root`, `main_entry_root`, nearby `exit_label`, `discovery_marker`, and portal latch. Temple `build(arena, layout)` is mounted under hidden root, `build_entry(arena, layout)` under entry root, replacing legacy slab/bush loops. Original altar/ember/rewards/guardians/save remain. Original garden terrain install comes from temple lane; circuit copies exact field records and mounts only active threshold floor at height0.5, beneath the shadow. Minimap uses section discovery_marker and actual field bounds; jungle main legend uses forest/bridge/river/ridge/gate.

Waterfall inspector and render isolation selector both recurse through section descendants. Six exact coordinates/dimensions/alpha materials are retained. Teleport-only cooldown expiry is explicitly insufficient; actual movement input permits intended exit. Current jungle visuals are the legacy flow version until the final helper lane is supplied. Final helper will own its waterfall sheets; do not leave section-generated duplicates.

`verify_temple_garden_courtyard` requires the actual nested mount instead of installing a fallback helper. `verify_hidden_combined_mount` checks real roots, active0.5 threshold, undiscovered/discovered anchors, and inherited wetland null roots/empty markers even with existing discovery IDs.

## Reproduction and source separation

Mac official engine: `4.6.stable.official.89cea1439`, executable SHA256 `974197a7e6663dba803ae97c3b2d987b77a37b6e70088400ecf0ccc591cbdfbc`. A byte-identical copy is in the task's runtime; engines run sequentially with unique custom userdata per fixture. Original project config, player, growth, profile, all four portal layouts are byte-identical to base. No user checkout/app/save or MASTER edits.

External task runner `../run_combined_qa.py` archives a committed SHA, imports it and logs each fixture under `../qa/<label>`. Tested source is `59ed6574b54e0568953357df8c15578dd37f4d94`: import+13 impact fixtures all passed, script/engine errors0. Retained portable evidence is `evidence/hidden-combined-v51/two-lanes-impact-summary.json`, with every fixture log and a source manifest. Latest task-local evidence is `../qa/two-lanes-head-impact/summary.json`; initial corrected-fixture evidence is `../qa/two-lanes-current-focused/summary.json`. Sandbox-before-data-dir crashes and a corrected new fixture's early marker-read error are retained as failed attempts, not successful tests. Linux-only parallel-runner unit tests cannot run their four process/isolation cases on Mac; two platform-neutral cases passed and the platform guard errors remain. Linux CI owns that validation.

After GUI slot assignment, `capture_hidden_combined.gd` captures the existing24 bounded states at960/1280. Away view is replaced by a legal reward approach with actual reward/save/once-per-run checks; temple guardian damage is synthetic, pressure is frozen. It uses existing test-window focus-pause disconnection, without user OS focus commands. No combined GUI was run at this checkpoint. Existing temple lane images in `evidence/temple-garden-v50` are reused lane evidence, not final combined captures.

## Remaining work and limits

Wait for parent final jungle SHA, recover its complete linear range, inspect/mount build/build_entry without waterfall duplicates, then test exact combined head and request/use one GUI slot after temple art. Full regression/fullCI, actual combined24 images and negative controls for duplicate/missing/misplaced water remain for final candidate. No merge/release/package/user app replacement.

Temple exact altar-center cylinder/ember Body~34% is a known preserved issue. Legal southeast reward approach at distance85 succeeded separately. Jungle prior water/FX partial occlusion is unresolved and cannot support a blanket98% claim. The jungle final coplanar fix and prior complete roundtrip render must be identified by distinct source hashes. Human art/place/fun acceptance, natural full runs and long-session performance remain unverified.
