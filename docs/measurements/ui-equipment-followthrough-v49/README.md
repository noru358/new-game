# UI equipment follow-through

Base: `a141b6cbe96c5143b23fefdaf9c809a90d3d3ae1`, branch `codex/ui-next-action-v49`.
GitHub actual clone and branch heads confirmed production at a141b6c and current-playtest/canonical at bad54d2. The latter is the merge base, with production 9 commits ahead. PR51's destination/card-copy changes are already included. Parent's later e860cb6 document update did not change this runtime base.

## Change and evidence

After buying gear, the existing generic equip button did not name the gear. At960, the existing purchase/equip explanation was below the action outside the current scroll view. After equipping, departure was available on another tab without a nearby next-action cue. These are code and native automated-input fixture observations; the attempted human-style GUI journey did not reach departure.

Reuse the existing instruction line immediately above the action: purchase requires separate equip; owned gear points to the named equip button; equipped gear points to the existing departure tab. Presenter reads committed Hub state only. No extra controls or departure-page information. Hub/settlement/save/economy/unlock/card/map/boss behavior is untouched. Existing action repetition still toggles equipment; it cannot rebuy owned gear.

- [Before: generic equip target, explanation below visible area](before-owned-960.png)
- [After: ownership cue and named equip target together](after-owned-960.png)

## Verification

Godot `4.6.stable.official.89cea1439`, Mac Apple M3, native OpenGL4.1 compatibility. UUID private userdata in separate QA copies; source project settings and user apps/save folders preserved.

- `verify_equipment_followthrough`: headless136 checks/0 failures; final native candidate147/0, baseline87/0 (new-copy expectations disabled only for baseline captures). Each native process exits0 and produces10 PNGs: fresh departure plus owned/equipped fresh and medium cases at960×540 and1280×720.
- Actual mouse selection/purchase, focused Enter equip, failed purchase/equip writes, repeated action toggles, Esc back, ordinary scene reload, corrupt/future save gates and visible instruction/action bounds. A fresh fixture begins with currency0, no owned gear or clear. It then receives synthetic RETREAT30→24 currency. A separate medium fixture receives synthetic SUCCESS0→50 currency and temple access. Neither is natural victory, economy acceptance, or a campaign run.
- Existing headless regressions: `verify_ui_flow`268/0; `verify_result_clarity`723/0; `verify_boss_countdown_ui`393/0; `verify_future_save_ui`11/0; `verify_hub_layout` and `verify_stage2_loop` pass. Final logs have no FAIL, SCRIPT ERROR, Parse Error or ERROR markers.
- Initial new-fixture failures came from clicking a gear row clipped outside the960 scroll area, which hit the camp Back control and subsequently left paused state. Explicitly scroll the existing list before selection. These failures are preserved locally and are not counted as product defects.
- First native captures opened Hub with `show()` without camp's `_update_prompt()` call, leaving a stale settings button over the1280 bank label. The fixture now invokes the same presentation refresh as ordinary E-open. Those initial images are not final readability evidence.

## Limits and handoff

CUA's first `getApp(Godot.app)` call took1536.3505seconds and returned the project-manager window, rather than the test window. No GUI action was sent. The passive observer stayed in camp (currency0/W_START, preparation=false); it is an incomplete observation, not a normal-speed run, death result, or evidence of focus-induced run pausing. Parent reclaimed the exact test process. No second natural-run attempt was made.

Human first-play comprehension, normal-speed first battle/first card/death/settlement/purchase/redeparture, three-map natural completion and a persistent profile across a separately launched interactive process remain unverified. Existing stage2 and result regression fixtures verify state contracts, not those human outcomes. Source entry and both final native fixture processes launch normally; scene reload retains purchases/equipment. Shared integration, CI, push acceptance review, merge, canonical, release and packaging remain parent-owned (only this branch's ordinary push authorized).

Raw logs and the full capture sets remain under `/Users/lty/Documents/Codex/2026-10-03/task-4/evidence/`. No common hub/hybrid_region/run_profile/project/document mount patch is required.
