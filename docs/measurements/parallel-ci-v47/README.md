# Two isolated verification batches

The user requested independent parallel work and faster delivery. Serial baseline d0f84da run37097226471:103 generic GDScript fixtures,446s generic step,525s whole job; exact completed inventory is preserved in serial-baseline.json. Actor-depth was dedicated rendered coverage, not dropped.

The candidate executes the same sorted inventory in two batches, sequential per batch, with two private byte-copy projects/imports. Every top-level fixture gets a new HOME and all XDG directories; its restart children inherit those paths. Authored resource .import files are preserved; generated .godot caches are not shared. Source, original userdata, terrain, gameplay and save format are unchanged.

Failure contract:240-second timeout, nonzero return, SCRIPT ERROR/Parse Error/line-start FAIL detection, complete inventory exactly once, both batches joined, per-fixture logs/status/durations retained. Child process groups are cleaned up. Dedicated preview lifecycle, actor rendering and historical price-tool checks remain separate, unchanged steps. Only one top-level engine per batch is allowed; restart children can temporarily raise engine count to four.

Six fake-engine tests exercise source/caller sentinel preservation, private dirs and inherited child paths, authored import-settings byte preservation, missing/duplicate coverage, nonzero and zero-exit error output, timeout descendants, import errors, symlinks and unsafe output. Parent reran them successfully. These are runner tests, not actual Godot performance evidence.

Exact integrated CI37098234365 succeeded. Artifact11264958302 matches all103 generic fixture names from serial baseline, split52/51, all passed; dedicated lifecycle/render/price checks passed. Generic step446→265s and whole job525→363s (one matched-game-code runner sample:40.6%/30.9% less wall time). Peak RSS was not measured; concurrency remains2 and no universal speed guarantee is made. PR49 merged production495dc28. Raw candidate summary and normalized comparison are included.
