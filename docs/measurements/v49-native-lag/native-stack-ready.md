# Next native stack measurement — preparation only

No Godot, sample attach, spindump capture, installation, security change or process termination was performed during this preparation. The integration task retains the engine slot. Product code is unchanged from `1cd01604`.

## Existing local tools and permissions

- `/usr/bin/sample` exists. Its locally installed help/man page supports `sample <pid> <duration-seconds> <interval-ms> -mayDie -file <path>`. The previous `evidence/baseline-temple-stack.txt` records a successful same-user capture of this exact Godot4.6 executable, PID17947, at1ms. This demonstrates earlier access; it does not guarantee a future attach. Use **8seconds/2ms** next, scoped to the PID returned by our own launch.
- sample suspends/resumes the target to collect all its thread stacks. The sampling interval is nominal; stack collection and symbol handling add cost. At2ms an8-second window has nominally4000 opportunities, and an83ms stall nominallyabout41; actual sampling counts/overhead must be read from the report. No zero-overhead claim or FPS comparison is valid. The text report is an **aggregate call tree**, not a timestamped per-sample timeline. A busy stack seen during12–20s cannot alone be assigned to the83ms hitch, and routine GL swap waits do not prove its cause.
- `/usr/sbin/spindump` exists. Local help/man explicitly support `-onlyTarget`, `-timeline`, `-timelimit` and output selection. Optional prepared command: `spindump <owned-pid> 8 2 -onlyTarget -timeline -timelimit 15 -o <path>`. It would retain chronological ranges rather than collect every process. **Live attachment privileges are unverified**; the preparation only inspected help. No sudo/root escalation is encoded. If the requested attach is refused, preserve the exact error and stop; do not automatically switch tools to evade the refusal.
- `/usr/bin/xctrace` is a launcher, but `xctrace version` fails: active developer directory `/Library/Developer/CommandLineTools` is a command-line-tools instance and the tool requires Xcode. Therefore Instruments/xctrace is currently unavailable. Full Xcode installation or developer-directory change is outside this preparation and was not attempted.
- The Codex workspace sandbox previously denied `ps`; read-only inspection/owned native runs required the ordinary task's reviewed host execution permission. A future sampler run may require the same tool-level permission to inspect the own PID and create its isolated user data. That is distinct from macOS task-attach privileges. Neither is silently assumed. Do not change SIP, signing, entitlements, privacy settings or tooling to overcome a denial.

## Prepared runner and alignment

`tests/run_v49_owned_stack.py` defaults to **dry-run**, with no process discovery, engine launch or sampler attach. Actual execution requires both `--execute` and `--slot-authorized`, supplied only after explicit parent slot allocation. It checks for existing engines only in execution mode and stops if any exist; it never terminates them. The runner does not accept an external PID: it can only attach to the Godot child it created. Every command uses structured arguments, no shell expansion.

The prepared QA scene prints one `STACK_WINDOW_START` JSON marker when **active game time reaches12s**, including the own PID and Godot clock/origin. The runner verifies that PID, region and12≤time<13 before attaching. It launches one8-second/2ms capture, targeting the existing stall at game15.4167s near player(2046.728,944). Record marker reception/attach request times; tool startup/symbol handling and sampling can shift the actual capture window, so inspect the generated report header. Do not infer exact start time solely from the request timestamp.

Normal native scene duration remains24s with a35-second total watchdog. Only owned child handles can be stopped. Logs, sampler report and metadata are written to a **new output directory**. No user app/save folder is touched; the copied project's save directory is a fresh `CodexV49Lag-UUID`. Nonzero engine or sampler exits are explicitly recorded as failures, even if a JSON file exists. No fallback, install, sudo, signing change or security modification is implemented.

Prepared source-only QA copy:

`/Users/lty/Documents/Codex/2026-10-04/task-3/qa/stack-prepared-0b97481`

It contains the marker and the previously proposed named pre-draw callback/disconnection at quit. That cleanup change remains **Godot parsing/native unverified**. Python AST, structural assertions and runner dry-run passed; dry-run did not create the execution output directory. The original scene-dependent parse failure and later cleanup crash remain separate evidence in the earlier report.

Preview only, safe while another task owns the engine slot:

```
python3 tests/run_v49_owned_stack.py \
  --engine ../runtime/Godot.app/Contents/MacOS/Godot \
  --project ../qa/stack-prepared-0b97481 \
  --output-dir ../evidence/stack-next-slot
```

After explicit parent allocation, parse the new fixture first in the isolated copy, then use that command with `--execute --slot-authorized`. For a separately authorized chronological capture, add `--tool spindump`; its access is not confirmed by this preparation.

## Next decision from a capture

The default sample can distinguish observed native call families (shader compiler/linker, texture/buffer upload, render/cull, GL driver wait) in the8-second region, but temporal attribution remains weaker than a timeline. Preserve unsymbolicated addresses rather than installing a new tool or declaring an unknown frame a shader compiler. A target-only spindump timeline, if permission allows, can align consecutive native ranges with the Godot marker/hitch. Neither measures GPU duration.

A sampled run is diagnostic evidence only: retain the matching render pre/post and scene-position trace, sampler interval/counts and attach errors. If there is no hitch, no useful symbolication, a late attach, focus resume or cleanup crash, report that limit. Do not implement a product optimization from a coincident aggregate stack alone. The pending blocker for execution is the **parent's engine slot**; xctrace additionally lacks full Xcode. There is no demonstrated sample attach blocker at preparation time, and spindump permissions remain unknown.
