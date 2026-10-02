# 정글 동선·원본 불투명 환경 — Mac lane 인계

현재 위치는 Stage3/B의 기존 사원·정글 표현 통합 한 구간이다. 이번 한 차례 배치로 전체 맵 볼륨, 첫 지역 완성, 재미·장소감·미감의 사람 수용을 완료로 판정하지 않는다.

## 기준과 소유

- 실제 원격 정본: `noru358/new-game`, `codex/current-playtest` = `93674fdb64dc1251e4de0d991cd34b47422576fe`. 최종 작업 중 `git ls-remote`로 다시 확인했다. 원격 변경·main 동기화·merge·force push 없음.
- 독립 Mac worktree: `codex/mac-route-opaque-v41`, 기준은 통합 담당의 제출된 `6dbe4b3e529d50f96bffa67c4a0e612065915876`다.
- lane 소유: 새 helper/data/tests/runner와 이 인계 자료. 공유 씬/기존 검사/공통 문서는 통합 담당 소유다. 공유 파일은 최종 원본으로 복구하고 아래 두 patch만 반환한다.
- 이전 `ZONE→LAMP` 후보는 재도입하지 않았다. 기존 강변 Zone/Fragment, 정면 Beast/Lamp, 역할 가중치·인원·스폰 budget·보상·히든·보스/승리·영구 저장 계약을 건드리지 않았다.

## 승인된 변경

계층은 **동남아 → 미정 중간 권역(새 이름·캠페인 계층 추가 없음) → 기존 정글 절벽 관문 → 물가 쉼터 / 북측 잔해 접근 / 관문 조망 → 낮은 포장·석재/식생 군집·빈 통행 공간**이다. 기존 열대 식생과 풍화된 사원 석조 제작법을 이어 사용했다. 장소 이름은 제작 데이터의 메타 정보이며 새 UI 이름표를 추가하지 않았다.

- 기존 parapet `(3420,1550,110,190)`을 `(3150,1810,110,190)`으로 옮겼다. 충돌과 석조 helper가 같은 record를 읽는다. 북측 접근과 남측 물가 우회는 모두 남는다. 추가 장애물 없음.
- 기존 남쪽 절벽 아래 `(2690,2260,1430,140)`에 원래 terrain 시스템의 실제 수면/통행 경계를 연결했다. 기존 장식 물 리본 28개를 대체한다. 전체 맵 면적·plateau·고도·ramp·route trigger는 동일하다.
- 전경 나무 `(3470,2200)`을 북측 `(3470,1575)`으로 옮겼다. 같은 불투명 나무·크기·높이와 trunk collider를 함께 이동했고, 북측 및 남측 접근이 열려 있음을 검사했다.
- 같은 갈대24·가장자리 돌10·낮은 뿌리3을 물가/잔해/오르막 가장자리로 군집했다. 가운데 통행 공간을 비우고 기존 flat/ramp를 따르는 낮은 포장만 helper로 보강했다. 새 높이·AI·스폰·저장·경제·발견 보상 시스템 없음.
- 사원의 전체 alpha fade, 성소/문턱 상부 cutaway, 수로의 지붕/보 제거와 상점·창고 alpha fade 경로를 제거했다. 원래 material·mesh·shadow·visibility가 유지되고 legacy flag도 다시 켜지 못한다. 기존 별도 field 전환과 캐릭터/FX/사망 표시, 원래 player-vs-boss sprite 우선 표시 기능은 유지한다.

원래 불투명 구조가 캐릭터를 덮는 경우도 그대로 보인다. 이것을 가독성 통과로 판정하지 않는다. 전 지역 가림을 배치로 해결했다는 주장도 하지 않는다.

## 실제 확인

설치된 Mac Godot `4.6.stable.official.89cea1439`, Apple Silicon GL Compatibility에서 실행했다. 다른 엔진 설치나 4.6.3 탐색 없음.

| 확인 | 결과 |
|---|---|
| 원본 불투명 환경 관련6개 script | 모두 PASS: temple/canal removal 계약, temple/opening environment, canal city, boss visibility |
| 정글 배치 관련6개 script | 모두 PASS: 신규route, 기존pass/section/warden, terrain coherence, surface overlap |
| 분리 patch로 새 격리 복사 재현 | 위12개 script 모두 PASS; patch는 복사본에만 적용 |
| 실제 정상 속도 보행·공격 | baseline/candidate × 960×540/1280×720 모두11경유지 PASS |
| 실제 지형·전투 | 높이80→480, 원래 강변 entry/crest, Zone 예고/장판, HP81 유지 |
| 원본 전체 구조 실제 렌더 | 사원 문턱/성소와 수로 동문/수문 × 두 해상도, original opaque snapshot 유지 |
| 저장/원본 보호 | 모든 최종 실행의 일반 설정·프로필/해금 a/b byte/부재 및 source hash guard 유지 |
| 인계 코드/렌더 동일성 | 분리 patch가 적용된 game 내용은 최종 실제 렌더 game과 해시 동일(UID 제외) |

동일 보행 루프 실측:

| 실제 창 | 기존 거리 / 보행 시간 | 후보 거리 / 보행 시간 |
|---|---|---|
| 960×540 | 4852.3 / 14.15초 | 4970.9 / 14.63초 |
| 1280×720 | 4858.4 / 14.15초 | 4958.0 / 14.48초 |

거리 증가는 약2~2.5%다. 이동량을 높이기 위한 장애물 추가를 하지 않았다. 세 군집과 빈 공간을 다르게 읽는지의 최종 판단은 사람에게 남는다.

실제 입력 fixture는 **시작 위치 한 번만 배치하고 경유지는 텔레포트 없이 보행**했다. fresh HP/loadout·자동 동행·고정 수비대 AI/공격/충돌/카메라를 유지하고, 주변 랜덤 스폰·성장 모달·이 관찰 창의 포커스 일시정지만 동일하게 끈 표본이다. 자연 한 판, 장시간 성능, 소리 청취, 난도/밸런스 수용 증거가 아니다. 원래 실행 중인 게임이나 일반 저장을 조작하지 않았다.

[대표 장소 전후3쌍](comparison.html)은 변경하지 않은 실제960 PNG를 한 페이지에 모았다. [원본 입력/렌더 수치](native-reports.json), [검사 및 보존 결과](checks.json)도 포함한다. 원본 전체 로그·두 해상도 화면은 작업 root의 `route-render-final`, `handoff-route-final`, `handoff-opacity-check`에 있다.

초기 제안 `(3060,1770)`은 기존 연결 비탈 끝점을 막아 회귀에서 탈락했고 현재 위치로 수정했다. 실제 ray fixture에서 simulation 전체를 끄면 static collision도 꺼진다는 문제를 바로잡았다. 나무 검사의 고정 원본 배열 참조는 actual route 배열로 바꾸었고, 검사 `is preload(...)` 문법 오류는 const type 참조로 수정했다. 실패 원본은 `route-check-v1/v3/v4`에 보존하며 PASS 숫자에 합치지 않았다.

## 통합 방법

먼저 이 lane의 새 파일을 cherry-pick한 뒤 통합 담당이 공유 파일을 검토하여 다음 두 patch를 장착한다.

```sh
git apply --check /ABS/route-worktree/patches/environment-opacity-mount.patch
git apply /ABS/route-worktree/patches/environment-opacity-mount.patch
git apply --check /ABS/route-worktree/patches/jungle-route-mount.patch
git apply /ABS/route-worktree/patches/jungle-route-mount.patch
```

`environment-opacity-mount.patch`는 공유 game5개와 기존 검사4개, `jungle-route-mount.patch`는 공유 jungle scene script와 terrain coherence 검사만 담는다. 최신 공유 편집과 충돌하면 통합 담당이 해당 hunk를 최소 장착한다. 새 helper를 cherry-pick하는 것만으로 production이 바뀌지 않는다.

실행 재현은 아래 runner를 사용한다. 두 patch는 **새 격리 project에만** 적용한다. 이미 장착된 소스도 reverse-check로 식별한다. HOME 변경 없음; UUID `LoopConquestMapTrials/<id>`만 사용하는 Mac custom data directory다.

```sh
python3 scripts/check_route_opacity.py --godot /ABS/Godot.app/Contents/MacOS/Godot --output /ABS/NEW-DIRECTORY --phase route
python3 scripts/check_route_opacity.py --godot /ABS/Godot.app/Contents/MacOS/Godot --output /ABS/ANOTHER-NEW-DIRECTORY --phase opacity
python3 scripts/check_route_opacity.py --godot /ABS/Godot.app/Contents/MacOS/Godot --output /ABS/THIRD-NEW-DIRECTORY --phase render
```

`--jungle-route-baseline`은 실제 씬에서 원래 정글 데이터를 선택하여 되돌릴 수 있게 한다. 환경 가림 제거는 사용자 명시 요청이며 별도 baseline flag로 복구하지 않는다.

## 남은 통합 및 미검증

- 부모의 **4분 타이머**, 신규 적/카드·영구 성장 확장은 다른 lane 소유다. 이 비교 baseline은6dbe4b3e이므로 화면에 이전5분 HUD가 남는다. 이 lane이 타이머를 되돌린 것은 아니다. 합본은 최신 timer/role/growth/boss-fix source와 장착해 전체 회귀 및 native 대표 화면을 다시 확인해야 한다.
- 본 lane은 원격 CI/export/최종 앱 배포·full natural run을 실행하지 않았다. 기존 사용자 앱/세이브/checkout을 보존한다.
- 맵 전체 볼륨, 첫 사원·정글 완성, 세 장소의 이름 없는 식별성, 전투 가독성의 선호·재미·미감, 경제/빌드 수용, 오디오·장시간 GPU는 미검증이다. 추가 확장이나 장식 반복은 이번 lane에서 진행하지 않는다.
- 공통 DEV_STATUS 갱신안은 `DEV_STATUS.fragment.md`로 분리했다. 통합 담당이 현행 묶음에 반영한다.
