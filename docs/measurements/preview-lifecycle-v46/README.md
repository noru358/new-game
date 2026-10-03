# v46 shared-preview cross-process lifecycle

## Result

`final-summary.json`: **PASS**, Godot 4.6.3 official Linux headless,
final-named scenario tested from `dc719abbac2baca3f801f7ef97819b64595b10b0` plus
its non-discoverable scenario rename (delivered v46 runtime unchanged).
Three separate scenario processes, **1,289 assertions**, no failures, script errors
or reported object leaks. A separate editor-only import bootstrapped the copied
project's resource/class cache. All four engine invocations exited 0.

There are **seven settlements, eight departures, one abandoned departure**. The
suite stops after Process C's final confirmed retreat, camp reload and independent
profile/unlock reread agree. This is one finite journey, not a soak test.

## Run

From this worktree:

```sh
python3 scripts/check_preview_lifecycle.py --godot /usr/local/bin/godot
```

The default creates a new unique evidence directory. `--output` may specify a
new, nonexistent directory inside the worktree. Existing directories are refused.
The launcher never cleans up or reuses old evidence/userdata. Each process has a
180-second failure timeout. A timeout or first failed phase stops the sequence.

## Isolation and source contract

- Real `game/field_preview_entry.tscn` and its script activate the default session.
  The test does not call `Session.activate` or override the save prefixes.
- Copy-only packaging settings point at the actual compatible preview save family
  `LoopConquest-FieldPreview-v45`; both default record stems are exercised:
  `first_region_shared_v45_profile` and `first_region_shared_v45_unlocks`.
- The entire project copy, HOME, XDG_DATA_HOME, XDG_CONFIG_HOME and XDG_CACHE_HOME
  live below one newly created owner-marked evidence directory. Before loading the
  entry scene, GDScript requires exact `OS.get_user_data_dir()` equality and matching
  ownership tokens in the evidence root, home and userdata markers.
- No ordinary user-data location is inspected, copied, read or deleted. The
  missing-directory save-failure probe is inside this owned userdata directory.
- Original `game/` files plus `project.godot` were hashed before and after:
  **210 files unchanged**. Copy hashes are checked between engine processes too.
  Initial import may add missing generated `.gd.uid` metadata only; those files
  are included in the frozen runtime baseline afterwards. Nothing is edited while
  a runtime process is running. No game files, source project settings, workflows,
  existing profiles, remotes or publication state were changed.
- Disposable copies/homes remain on disk and are ignored in Git. Evidence logs,
  model checkpoints, slot hashes, guard manifests and failure records are retained.

## Sequence and ledger

### Process A — 481 assertions

1. Real entry → shared camp → temple-circuit. No synthetic development clear or
   six-level unlock seeding. Explicit 100-currency success fixture; real growth APIs
   earn two lifetime levels and actual offered-card selections.
2. Camp legally buys W_FLOW for 35, then separately equips it; buys VITALITY for20.
3. Real departure to jungle-south; lifetime count remains two until the test injects
   XP through the growth API. Two more levelups, 80-currency first-clear fixture.
4. Real departure to wetland-run; two further levelups, 80-currency first-clear.
   Exit on its committed result screen **before returning to camp**.

A ends with currency355, profile generation9, all three clears, temple relic,
W_FLOW equipped, VITALITY1 and lifetime/unlock generation6. First-clear awards are
150,130,130. Result-only `last_award`, `last_lost`, `last_first_clear` and
`last_mod_award` are explicitly expected to reset on reload.

### Process B — 589 assertions

1. Fresh entry/camp opens byte-identical A records and checks every durable profile
   field, unlock count/generation, all three milestone gates and reset result fields.
2. Legally buys W_ECHO45, equips separately and buys/selects supply12. Temple
   departure consumes the supply durably; real health-change signal spends its heal.
3. Synthetic boss-entry/death setup reaches the real retry modal. Its wired Retry
   button restores the player/spawns a boss without refunding supply or changing
   durable bytes. The real death path on a second fixture death settles defeat:
   earnings111, loss56, award55.
4. Jungle retreat is requested, canceled through its wired button, requested again
   and confirmed. An absent-directory write failure leaves the old bytes/money/
   generation unchanged and blocks both return-button signal and R. Failed retry
   remains uncredited; restoring the original prefix and clicking Retry commits
   once: earnings73, loss15, award58. Repeated retry/finish/show is write-free.
5. Wetland repeat success with earnings80 awards100, with **no second first-clear
   bonus** and exactly one previously unowned valid option. The recorded sample
   awards STEADY; choice is calculated from the actual generated run ID and legal pool.
6. After the sixth settlement, another legal supply12 purchase is consumed by the
   seventh departure. One more XP-based lifetime levelup is saved. The process exits
   during the real pending card modal with uncommitted currency777, HP37, time123.25,
   kills9, a temporary U_EDGE card, retry-used flag and temporary companion focus.

The interruption's card/focus/HP/time/retry values are explicit transient fixtures.
The actual focus controller is injected solely to create realistic target weakref
state; no COMPANION branch purchase or gameplay acquisition is claimed. The
permanent profile remains generation20/currency499; unlock generation7/lifetime7.
The last settled ID still names the sixth run, while last-launch names the abandoned
seventh departure. Existing U_STEP=2 is an accepted built-in movement baseline,
not a leftover temporary card or unintended unlock seed.

### Process C — 219 assertions

Fresh entry/camp checks B's exact bytes and all durable fields. Purchases, clears,
option and seventh departure's consumed supply remain; currency777 was never banked.
An eighth real departure starts full HP110, time/earnings/XP/cards at baseline, no
retry used/pending, no focus target/controller, no stale overlay/pause/result state
and no refunded supply. Final confirmed retreat with earnings25 loses5 and awards20.
Camp and independent profile/unlock rereads agree at **currency519, profile
generation22, unlock generation7/lifetime7**.

Every scene transition checks old scene/player/simulation/group weakrefs have been
freed and every remaining combat/effect group member belongs to the current
simulation. Repeated departure IDs, settlements and retry calls are checked for
idempotence. JSON snapshots are normalized so int/float representation does not
produce false failures.

## Evidence and harness corrections

`attempt-05/` is the final-name successful complete sequence. Publication evidence
is limited to this README, `final-summary.json`, `final-ledger.json` and
`process-A.txt`/`process-B.txt`/`process-C.txt`. The summary includes distinct process
IDs, assertion counts, final state and identical before/after source-manifest SHA256.
The ledger preserves exact durable state, slot hashes, generated run IDs and the
interrupted transient fixture. Complete raw checkpoints, before/after manifests,
all earlier failures, disposable projects and isolated userdata remain locally
under ignored `attempt-*/` directories; **none are committed or packaged**.

The final scenario is `tests/preview_lifecycle_scenario.gd`, deliberately outside
the existing CI `verify_*.gd` discovery pattern. It must run through the guarded
Python launcher, never directly against an ordinary project/userdata namespace.
Parent integration owns any separate workflow launcher step.

Earlier attempts are preserved and not counted as passes:

- `attempt-01`: supplied binary pathname `/usr/local/bin/godot4.6.3` did not exist.
  Available `/usr/local/bin/godot` identifies itself as official4.6.3.
- `attempt-02`: importer added missing `.gd.uid` metadata in the disposable copy;
  guard initially rejected these expected generated additions. Original files did
  not change. Import-only UID generation is now narrowly allowed then frozen.
- `attempt-03`: test expected an empty fresh card dictionary; actual accepted
  movement baseline is `{"U_STEP":2}`. Corrected the assertion to retain that exact
  baseline while requiring no selected temporary cards. The first divergence is
  retained, including its slot hashes and ledger.

`attempt-04` passed the original scenario name. After review identified the
repository-wide `verify_*.gd` auto-discovery risk, the scenario and launcher paths
were renamed, then the full suite was rerun once as `attempt-05`.

No runtime defect was found or fixed. No normal-play bot behavior was interpreted
as a game defect.

## Limits

Injected outcome/currency/XP/boss setup verifies state contracts, not natural wins,
real-time three-map play, balance, difficulty, fun, audiovisual quality, long GPU
sessions, Windows/Mac behavior or human acceptance. Orderly process exit while a
card modal is open verifies the lack of mid-run saving; this is **not power-loss,
kill-during-write, filesystem-corruption or transaction-atomicity durability QA**.
Profile discovery/awakening/attack-branch/slot fields are checked at their unchanged
baseline values; the suite does not acquire those unrelated features. Focus setup
is synthetic and does not certify branch acquisition. No packaged app is produced.
