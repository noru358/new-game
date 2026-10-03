# Fennec idle trial v1

## Status / 진행 대시보드

- 현재 단계·세부 위치: 2단계 메타 연결/첫 권역 제작 중, 3단계 진입용 주인공 아트 생산 최소 시험.
- 이번까지 완료: 원격 기준/ancestry 확인, Library 두 원본 실제 픽셀 열람, imagegen 3방향 파생 PNG, import 정규화, 전용 adapter/preview/검사. 공식 Mac Godot4.6stable headless 실패0.
- 바로 다음 작업: 부모 GUI 슬롯에서 native7장 촬영 → 부모가 얼굴/꼬리/실루엣·크기를 보고 animation 범위 결정.
- 사용자 확인·미검증: 시안 시험 승인만 있음. 최종 디자인/방향별 동일성/사람 미감·실제 960·1280 가독성/native PNG는 미검증.

## Grounded base

Independent clone and branch `codex/fennec-idle-sample-v1`, remote actual repository `noru358/new-game` (public; connector push permission confirmed). PR54 is open draft with head `296bde54f987372750e652c608c62b8e6309192c`. Actual merge-base with production is `1aac501f097ff565f5fd249b9411ab91e64b3223`. Main is older `2f2c6803db97740e4a6131cd25ead83a9df6c38f`. No main/production/canonical update, app replacement, merge, or package.

AGENTS.md, DEV_STATUS.md, MASTER§8.1/8.2/10 read. Repo `.agents/skills` does not exist. Current direct attacks, moving slash and companion contracts are preserved.

## Pipeline and delivered files

Current simulation is `CharacterBody2D`; hybrid_height creates `Body:Sprite3D`, billboard enabled, linear filtering, depth-writing alpha discard. Original SVG is64×96, pixel_size0.01, fixed camera-up center offset. There are no existing directional animation sheets or AnimatedSprite nodes. Facing originally only flips a single texture and attack presentation rotates the plane.

The adapter uses three individually generated idle raster PNGs. All are384×448, foot anchor(192,416), equal384px ear-to-foot used height. Pixel size0.0025 gives0.96world height, equal to original texture height. PositionUP0.04 and offset(0,192) follow existing enemy grounding convention; actual footing still needs native inspection. Foot horizontal anchors were manually picked from boot/pelvis alignment rather than alpha centroids, which a tail would shift. Manifest retains crop bounds, scale and source hashes. Normalizer only crops/resizes/pads; it preserves alpha and never paints or redesigns. Semitransparent edges are discarded at0.5 consistent with terrain depth. Source RGB in transparent pixels can look like a glow in previews; sampled outer pixels were alpha0 and do not render.

`game/fennec_idle_adapter.gd` selects front/side/back from camera horizontal/toward projections; side alone flips left. No simulation writes. Existing modulation and attack plane transforms remain inherited. This is still idle art during movement/attacks; it does NOT claim animation production.

`tests/fennec_idle_preview.tscn` subclasses the actual temple region and mounts the adapter without editing common source. It refuses to start unless userdata containsFennecIdle-. `patches/fennec-idle-mount.patch` is a checked, unapplied common renderer mount proposal with opt-in `--fennec-idle-trial`; integration belongs to parent.

## Source references and prompts

The approved full concept and tail-corrected fiveview Library originals were materialized with the current Library resolved-reference transfer helper on the consumer Mac. Actual pixels and exact byte sizes1,931,801 and1,675,732 were verified. Original files are OUTSIDE this checkout and are NOT uploaded. Library identities: `libfile_3ce9a7b07060819195359077a5f85bd7`, `libfile_c2b5787aa664819186bf247ef912cac6`.

Built-in imagegen generated each direction separately using both originals: front uses approved front standing identity; side uses third true side figure facing right; back uses fifth rear figure. Prompt set: identity-preserve; faithful extraction/adaptation only; cute animation face/brown highlighted irises, cream muzzle, short neck, huge ears, sturdy about3head body excluding ears; navy overlapping cheollik coat, cream collar, small dark shoulder pads/bracers, orange-rust sash, low black traditional leather shoes; relaxed idle, grounded feet; exactlyone tail whose narrow root emerges behind pelvic midline below sash and coat rear seam; same silhouette/colors; full figure with margins; true transparent alpha/no shadow/background/text/effects/weapons. No new face/outfit design. Back result was returned inline after executor reconnect and decoded into this consumer Mac before normalization. A redundant front extraction request was issued before alpha0 was identified; its later output is unselected and outside repo. No other art is substituted.

## Checks and limits

Engine: officialMac `4.6.stable.official.89cea1439`, executable SHA256 `974197a7e6663dba803ae97c3b2d987b77a37b6e70088400ecf0ccc591cbdfbc`, byte-identical independent copy of locally discovered verified runtime. Only one engine runs at a time. Original project config/player/render/profile/growth are byte unchanged. QA project only has a fresh UUID userdata override; source settings and user saves are untouched.

Headless fixture: seven posed cases (three directions×960/1280 plus one960 front crown-height comparison), eight checks each: canvas, pivot, billboard, depth, collision-radius preservation, camera right/toward/away mapping.56 assertions, failures0. `evidence/fennec-idle-v1/headless-report.json` and `headless.txt`. Headless run cannot prove rendered readability. Initial userdata sandbox error and fixture type-inference parse errors were corrected; these failed attempts are not counted as PASS.

With temple camera size9, total projected height is57.6px at960 /76.8px at1280. Manually inspected front forelock landmark y290 vs used ear-top49/foot1466 gives crown-to-foot1176/1417≈83.0% (an approximate artist landmark, not automatic anatomy). Baseline body height47.8px at960. The ONE comparison uses1.205× pixel size, giving full69.4px/body57.6px; collision/camera unchanged. Other directions' crown landmarks and exact boots contact remain native/manual checks.

## Reproduction

Use Python>=3.10 with Pillow. `scripts/run_fennec_idle.py --engine /absolute/Godot --output /absolute/new-qa-dir` creates a private project and runs sequential import+headless. Add `--native` ONLY after parent's GUI slot allocation; native fixture has eight bounded process frames plus force_draw per frame and validates actual960×540/1280×720 PNG sizes. It never waits indefinitely onframe_post_draw. Engine processes have120s timeout. The parent should inspect front960, front-body-height960, side960/back960 then1280. No GUI has been launched in this lane yet.

Open blockers: parent GUI slot (currently palace lane), native pixel review, and parent's size/animation-scope decision. Parent-notification calls began returningTransportclosed after Mac executor reconnect; commentary and this handoff retain last successful steps.
