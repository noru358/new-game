# Provisional 1.205× direction/motion trial — preparation only

Parent reviewed actual front960/front-body-height960/side960/back960 from `a7270f0` and selected the existing crown-height comparison as a temporary trial size. This is not final user approval. No new art, common integration, merge, package, user app/save modification or engine execution in this preparation.

## Ready code

- All three directions now use pixel_size0.0025×(1417/1176)=0.0030123299. At unchanged camera9 and960×540: ear-inclusive whole69.40px, manually estimated crown-to-foot57.60px.1280 whole92.54px/crown76.80px. The59-ish/69-ish values MUST NOT both be described as body heights. Camera/collision/attack timing remain unchanged.
- Existing generatedPNG bytes are unchanged. Dark, alpha-scissored sole pixels in rows407–415 give contact-span midpoint x190front/x187side/x195.5back vs nominalx192. Adapter offsets are+2/+5/−3.5px, and mirroredside−5px. Verticalfooty416 remains unchanged. This is a geometric boot-contact estimate, not final anatomical acceptance. It corrects algebraic pivot error only; physical/native alignment remains to be checked.
- Godot4.6 official [Sprite3D source](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/scene/3d/sprite_3d.cpp) flips UVs independently of destinationoffset. Side flip therefore reverses the compensation. Measurement and source hashes are in `evidence/fennec-motion-v2/anchor-measurements.json`; all four view/flip cases have algebraic residual0.
- `tests/capture_fennec_motion.gd` is a prepared real-input fixture using existing Input actions/events through the inherited actual player/simulation. It walks right, turns left/back/front, uses one existing dash and directattack tap, then settles. It never invokes private attack/dash methods or rewrites combat/player fields. A physics-boundary observer watches short action states even between slow native renders.
- Per-render samples record player/velocity/facing, chosenview/flip, footoffset/local pivot residual, renderground, dashstate, attackstep/sequence and inherited plane rotation.21representative960PNG frames are prepared across7shortphases;45000ms fixture budget and120s process timeout. Actualsize assertions and force_draw are bounded; no frame_post_draw await.
- Static idle drawings remain in movement/attack states. The next native sequence observes direction swap/foot pivot/tail stepping; it does not produce finished walking/dash/combat animation. Tail position consistency is a parent pixel-review item rather than an invented automatic PASS.

## Slot-only next command

Use existing `scripts/run_fennec_idle.py --engine /absolute/Godot --output /absolute/fresh-qa-dir --motion` for the allocated headless check, then a fresh output with `--motion --native` for GUI. Runner creates a UUID FennecIdle userdata copy and leaves originalproject.godot intact. It must NOT run before parent allocates a slot. Old idle fixture remains ear-inclusive baseline+one crown comparison for historical reproducibility; only its measured horizontal anchor expectations were updated.

Preparation evidence: PIL image-only measurement and zero-residual algebra passed; Python runner syntax compile passed; scoped diff has no commonplayer/render/project/profile/growth changes. Read-only approved ps after reconnection found0Godot processes. New GDScript compile/headless/native sequence is intentionally unrun; previous56/0 and7PNG belong to a7270f0, not this updated adapter.

현재 단계·세부 위치: 첫 권역 캐릭터 최소 시험 / 이번까지 완료: 부모 선택 크기3방향 일치·발 앵커 측정/adapter보정·입력 관찰fixture 준비 / 바로 다음: 부모 슬롯에서 컴파일·headless→native확인 / 사용자 확인·미검증: 임시크기 선택만, 움직임/발·꼬리 가독성/최종디자인은미검증.
