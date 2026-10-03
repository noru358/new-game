# 사원 표면·조명 실험 — 최종 아트 후보 미채택

부모는 실제 중정 전후 픽셀을 확인하고 이 후보를 **최종 아트 샘플로 채택하지 않았다**. 중앙 바닥은 과하게 밝고, 벽·계단의 촘촘한 검은 띠는 마모보다 노이즈로 읽힌다. 참고의 중간규모 식생, 유기적인 돌 형태, 장소 가장자리 군집도 부족하다. 숫자 미세 조정을 중단하고, 다음 에셋 형태·배치 설계는 부모에게 돌려준다. production 장착·merge·패키지·사용자 앱 변경은 하지 않았다.

현재 단계: 첫 권역 제작의 사원 대표 아트. 이번 완료: 되돌릴 수 있는 표면/조명 실험과 국소 실행 근거. 바로 다음: 부모의 대표 에셋 설계. 사람 미감·재미·자연 완주·소리·장시간 성능은 미검증.

## 전후 실제 화면

| 장소 | 기준 | 후보 |
|---|---|---|
| 중정 960 | [before](before-court-960.png) | [after](after-court-960.png) |
| 중정 1280 | [before](before-court-1280.png) | [after](after-court-1280.png) |
| 회랑 960 | [before](before-cloister-960.png) | [after](after-cloister-960.png) |
| 회랑 1280 | [before](before-cloister-1280.png) | [after](after-cloister-1280.png) |

원본 PNG는 각각 `before-raw/`, `after-raw/`에22개씩 있다. 같은 실제 카메라/이동 입력과 고정한 실제 적 Body·공격 예고를 사용했다. 별도 static overview2장은 본선 카메라 증거와 구분한다. 사용자 참고 그림은 consumer Mac의 비공개 폴더에서만 열람했고 저장소에 올리지 않았다.

## 정확한 소스와 범위

- Remote: `https://github.com/noru358/new-game.git`, 소유자 `noru358`, repository ID1387549125. 실제 원격/PR40/ancestry를 확인했다.
- Base production: `1aac501f097ff565f5fd249b9411ab91e64b3223`. canonical `686228f1d2f7cad0f09311c2006f46c6c16ce9d3`는 그 조상이다. main을 기반으로 삼지 않았다.
- Tested candidate: **`3c9f3cf4978077a517a6d6ca652fe964d4e5200a`**. 기준 보행은 `af5df78bd78f67c48a811a1af363bd6536dd7662`이며 모든 `game/` SHA256이 후보와 동일하다. 기준 flag가 finishing을 건너뛴다. 후기 커밋은 근거·인계·mount/status patch만 추가한다.
- Branch: `codex/temple-material-slice-oct03`. 독립 clone과 새 UUID userdata를 쓰며 launcher receipt에서 원본 game/project 파일 보존을 확인한다.
- 현재 씬에는 미장착. `game/temple_surface_sample.gd`와 `.gdshader`, 전용 검사/런처만 추가했다. 공유 `temple_circuit_run.gd`·DEV_STATUS는 patch로 인계한다.

분석 당시 병목은 조명받는 toon 석조의 넓은 단색 면과, 흰 ambient0.75/sun0.65의 평평한 재료·원경 구분이었다. 모든 재질을 unshaded로 가정하지 않았다. 실험은11기존 mesh의 위치·색·인덱스·AABB·surface 수를 유지하고 coplanar 연결 면 UV와 물리 폭 UV2를 추가한다. shader의 마모는 면 경계를 따르고 바닥 변화는1.8%로 제한한다. alpha·변위·새 장식·정지 그림 덧씌우기는 없다.

기존 양면 수평 면의 반대 방향 노말을 shader 조명에서 분류한다. 명도·태양 그림자를 수정했으나 실제 결과가 목표 아트에 충분하지 않음을 부모가 판단했다. 기존 이끼·식생·먼 수관에 표면만 적용해, 새 유기적 조형이나 풍부한 식생 군집이 만들어졌다고 주장하지 않는다.

본선 밖에서는 원래 Environment resource, 태양5속성, terrain material을 복원한다. hidden 코드와 캐릭터를 수정하지 않는다. 게임플레이·저장·경제·240초 보스·카메라 계약을 유지하며 자동 투명화/컷어웨이가 없다.

## 통과와 실패를 구분한 검증

- 공식 Mac Godot `4.6.stable.official.89cea1439`, Apple M3 OpenGL4.1 Metal/Compatibility. 알려진 공식 CLI 경로를 사용했다. CUA/getApp이나 사용자 앱 창을 조작하지 않았다.
- 전용 구조195678조건 실패0. UV의 두 삼각형 대각선을 마모 경계로 오해하지 않는 검사, 원본 위치/색/인덱스/형상, 범위/복원/idempotence 포함. 노말 재압축 최대 벡터 오차0.0001291943. 설치CPU 약194ms 일회성(장시간 통계가 아님).
- 기존 사원 run 검사 실패0. 기존 장소13443조건/5148광선 실패0, 새 기하 가림0. 재질 변화 이후의 시각 실패를 이 기하 검사로 덮지 않는다.
- 기준 보행: 정상 입력4지점(두 장소×두 크기),22PNG,26.533active초, 오류0. 후보도 같은 보행시간/22PNG를 회수했지만 **Body98% guard4실패**, 비영exit1을 유지한다. 수집 모드는 실패를 지우지 않고 마지막 보고서/exit에 되돌려 두 장소를 비교 가능하게 한다.

| 장소/크기 | 배우 Body 기준→후보 | 적 Body 후보 | 예고 후보 | draw calls 기준→후보 |
|---|---|---|---|---|
| 중정960 |99.68%→96.93%|99.76%|100%|110→122|
| 회랑960 |99.37%→96.83%|100%|100%|109→119|
| 중정1280 |98.82%→96.47%|99.86%|100%|113→125|
| 회랑1280 |98.82%→96.35%|99.93%|100%|112→122|

Body 픽셀 guard는 표면 대비/그림자의 영향을 받을 수 있으나 원인이 확정됐거나 기준을 통과했다고 표시하지 않는다. raw Body 비교에는 원래 공격 예고의 몸체 중첩도 포함되므로 same-FX player/적/tell 결과를 별도로 보존했다. 이 경우의 baseline/candidate 원시 보고서는 [comparison.json](comparison.json), [before-walk.json](before-walk.json), [after-walk.json](after-walk.json)에 있다.

새 삼각형 위치는 없지만 그림자 pass로 렌더 primitive 수는 중정30733→58155, 회랑31024→58422로 늘었다. draw call도10~12 증가했다. 새UV/복제Mesh/원본 진단 metadata와 shadow buffer의 메모리 비용을 별도로 측정하지 않았다. 비용이 없다고 주장하지 않는다.

전후 liveAI는 각각 네 개의10.983active초 표본으로 실제60Hz 이동·공격·예고·적1처치씩을 관찰했다. 두80HP 적의 합성 배치, ambient/growth modal/wisp 억제를 동일하게 적용했다. HP와 궤적은 시간·hitstop 등에 따른 실행별 차이가 있으므로 미감·난도·재미 수용 증거가 아니다. frame interval p95는 기준17.14~18.23ms, 후보16.93~17.54ms지만60fps cap과 짧은 표본이어서 성능 향상으로 해석하지 않는다. [before-live-combat.json](before-live-combat.json), [after-live-combat.json](after-live-combat.json) 참조.

## 실행과 인계

GUI 슬롯을 부모에게 요청한 뒤 전용 런처를 실행한다. 헤드리스 엔진과 GUI 엔진은 각각 직렬로 사용했고, 실험 마감 후 본task GUI PID0개를 확인하여 통합 담당에게 반환했다.

```sh
python3 scripts/launch_temple_surface_sample.py verify --godot /path/to/official/Godot --destination /fresh/check
python3 scripts/launch_temple_surface_sample.py walk --godot /path/to/official/Godot --destination /fresh/before --native-slot-granted --baseline
python3 scripts/launch_temple_surface_sample.py walk --godot /path/to/official/Godot --destination /fresh/after --native-slot-granted --collect-failed-visibility
python3 scripts/launch_temple_surface_sample.py combat --godot /path/to/official/Godot --destination /fresh/combat --native-slot-granted
```

`--temple-surface-baseline`은 finishing을 끄는 직접 엔진 flag다. 후보는 자동 production 통합하지 않는다. 추후 별도 시험에만 `patches/temple-surface-sample-mount.patch`를 적용하면 `_ready` 뒤의 한 줄로 장착되며, 제거하면 되돌릴 수 있다. 상태문서 수정안은 `patches/temple-surface-sample-status.patch`이다. 두 patch는 base에서 apply-check로만 검증하고 공유 파일에는 적용하지 않았다.

초기 native 실패 기록은 로컬 작업 폴더에 별도로 남긴다: focus-loss pause의0PNG 실패, Window/drawable mismatch의7PNG 실패, occluded-window frame signal 대기와 자체PID 종료, 두 번째 해상도에서 남은 합성 입력에 따른 follow 실패. 모두 성공 집계에서 제외한다. 최종 fixture는 bounded `force_draw(false)`, 정확 PNG 크기(리사이즈 없음), 합성 press와 release의 명시적 짝을 사용한다. 제품 pause/input/camera는 바꾸지 않는다.
