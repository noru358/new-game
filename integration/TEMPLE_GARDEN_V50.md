# 사원 숨은 안뜰 v50 인계

- 단계/위치: Stage3 B, 동남아→큰 폐사원→회랑 뒤 선택 안뜰. 첫 권역·자연 완주·미감 수용 완료가 아님.
- 완성: 입구 회랑 흔적→끊어진 수로→연못 서북의 곧은 석재 뜰 / 남동의 넓은 흙길과 낮은 뿌리·정원석→작은 수반/기존 제단→같은 문턱 복귀. 큰 성소/정글 성역을 복제하지 않음.
- 파일 소유: `temple_garden_courtyard_data.gd`, `temple_garden_environment.gd`, Original의 garden install, 전용 검사/fixture. `temple_garden_layout.gd`와 circuit layout 좌표 변경0. Original의 본선 vestibule/다른 본선 기록 보존. circuit이 Original에서 같은 필드 기록을 복사함.
- 부모 장착: `patches/temple-garden-courtyard-mount.patch`는 canonical section용 리뷰 patch. flow section에는 `hidden_visual_root.add_child(Helper.build(arena, layout))`, `main_entry_root.add_child(Helper.build_entry(arena, layout))`로 이식. 기존 slab/bush 두 루프만 교체하며 출구 라벨·포탈·불씨·기존 제단/보상은 flow 소유. 부모의 가시성/발견/재진입 debounce와 통합 후 재확인 필요.
- 구조검사: 두 실제 씬 동일 field records, 3 opaque batch, 128545 assertion/4168 합법 camera actor rays 가림0. 70 disjoint floor pieces; 보행 포장 최대0.74unit은 실제 Shadow 하부보다 낮음. 새로운 interior/southeast 턱21이며 rear perimeter115. 자동투명화/지붕숨김 없음.
- 기존 headless 5개 PASS: garden_transition, temple_section(수호3·각성·실패 저장·1런1회), temple_circuit_run(240초·정산/저장), terrain_coherence, surface_overlap. 독립 QA userdata, 엔진1개씩 순차.
- 렌더 tested SHA: `11fef3d70566d5a029b68f617a52af77b0bc741d`; 게임 코드는 `b0195780aa4baef67f852aecd48d6e707e3b7e6c`. Godot4.6stable, AppleM3/OpenGL4.1 Metal compatibility. baseline은 production `1aac501`(canonical686228f 직계 자식, 게임동일).
- 실제960/1280: baseline/candidate 각26 정상입력 체크포인트·72PNG. 각각 총 active68.10/61.7667초, wall101.94/95.55초. MOVE_SPEED300/mult1.12/카메라9 보존, waypoint teleport 없음(초기 mainRETURN1회 설정); 기존 실제 양쪽 포탈 tick 사용. 시간·수호 delay/적 공격압박 동결, 시험창 focus pause 연결해제 양쪽동일. 후반에 부모 flow 창과 짧게 중첩(정확 시간 미측정); 성능/자연 플레이 증거로 쓰지 않음.
- strict 픽셀 검사: 후보2실패 그대로 유지. ALTAR 정확 중심에서 기존 원통/불씨가 몸을 덮음. 전후960 342/1000=34.2%,1280 599/1782=33.6139% 동일. 새 배치가 이 문제를 고쳤다고 하지 않음. 다른 보행 표본은 기준 대비 새 가림3%초과0; 북 연못0%→100%, 입구95.5%→100%. 같은 실제 배우/예고를 둔 scenery Body 최소98.6998%, 적 Body/예고100%. 공격 예고의 기존 몸체 중첩도 보존.
- 첫 focus-stall 표본과 v2 크기불일치 표본은 폐기. v3 exact PNG/window size 재시도0, 스크립트 오류0. baseline 기존0% 가림은 usable reference를 보존하고 경로를 계속해 수치 실패로 기록.
- 핵심 전후2장: `evidence/temple-garden-v50/before.png`, `after.png` (동일 static overview,1280). 전체144PNG는 로컬 작업공간의 baseline/candidate-render-v3에 보존. source manifest·구조/회귀·픽셀 보고서는 같은 evidence 폴더.
- 보상 접근 PASS: ALTAR+(60,60)=(8360,540), 실제 (8360,540.8008)/거리85.4209<105. 정상 입력0.55초로 접근, 실제 수호3/예약0 이후 보상 성공·한런1회·각성/발견 reload·같은 RETURN 확인. 수호 처치는 기존fixture의 합성 고피해이며 자연 전투 주장이 아님.
- 바로 다음: 부모 flow mount·합본 회귀/입출구 표기 확인. main/production/canonical/merge/force/패키징/사용자앱 변경 없음. 기존 ALTAR 중심 가림과 사람의 장소감·미감·재미는 남음.
