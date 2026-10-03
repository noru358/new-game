## v42 후속 정글 관문 대표 아트 실험 — 2026-10-03 KST

- Stage3/B 기존 지역 대표 아트 샘플. parent 승인으로 관문 접근의 석주8·바위10 및 기존 석계단12 표면 마디만 개선했다. 독립 `jungle_worn_stone_visuals.gd`가 repo-native ArrayMesh/SurfaceTool을 사용한다. 건축의 규칙성과 자연 암석의 비대칭 넓은 facet을 대비하며 전체 맵 확장/새 기술/이미지 생성은 없다.
- v42 local f21f2b63 기준 helper/assets lane. 공유 `jungle_pass.gd`·`hybrid_height.gd`는 커밋하지 않고 `patches/jungle-worn-stone-mount.patch`로 통합 소유자에게 반환한다. 실제 actor/terrain/depth 버그 수정과 최종 합본 회귀는 별도 통합 담당 소유다.
- 공식 Godot4.6 Mac OpenGL/Apple M3의960/1280 기준/후보 정상 이동·공격 렌더4회와 기존 정글/route/terrain coherence/surface overlap4회귀가 통과했다. 기존18개 노드/표면·transform·material, terrain/collision 레코드와 일반 저장을 보존했다. 새 석재는 기존 BoxMesh 외곽 안이며 계단 표면은 원래 ramp_height 위 최대2px(기존선3.5px)이다.
- 전체 추가geometry는1064삼각형. 동일 정적 시야 drawcall은960의215/221,1280의218/224로 전후 동일하다. 전후PNG·로그·결과표는 `docs/measurements/jungle-worn-stone/`에 있다. 사람 미감/가독성·장시간 성능·actor/depth 합본 회귀는 미검증이다.
- 다음: 통합 담당이 helper 커밋과 shared mount를 합친 뒤 같은 구간의 actor/depth 회귀 및 최종Mac 렌더를 확인한다. Stage3/C 사람 빌드·경제 수용, D첫 지역 완료와Stage4출시 품질은 계속 남는다.
