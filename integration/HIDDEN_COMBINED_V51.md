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
