# 정글 강변 입구 수비대 비교 — v41 맵 lane

**결론: 수비대 교체 실험 미채택. 제품의 기존 배치와 경로 차이를 유지한다.**

기준은 실제 원격 `noru358/new-game` / `codex/current-playtest`에서 확인한 `93674fdb64dc1251e4de0d991cd34b47422576fe`다. 작업은 Mac의 별도 `codex/mac-map-lamp-v41` worktree에서 수행했다. 기존 checkout, 앱, 진행 저장, 공통 문서는 수정하지 않았다. 이번 제출 마감 뒤 새 맵 개선을 시작하지 않는다.

## 제작 계층과 범위

옛 동양권 → 동남아의 기존 열대 석조·식생 구상 → 정글 관문 맵 → 석교 직행/강변 우회 입구 → 기존 수비대 한 명이다. 미정 중분류를 새로 만들지 않고 MASTER/PRODUCTION_NEXT의 기존 구상을 따른다. 석교는 낮은 잔해가 좁힌 정면 통로와 돌진45%, 강변은 넓은 쉼터/연결 비탈과 원거리25%·지원10%가 이미 있다. 문화·지형·길·소품·가중치를 다시 만들지 않았다.

지정된 강변 입구 `(2820,1930)` 한 명을 ZONE→LAMP로 대체하는 후보만 비교했다. 해당 역할의 XP4·화폐2가 같아 입구 두 명의 총 XP6·화폐3이 보존된다. 기존 체력은 ZONE32/LAMP30이고 기존 AI/수치를 그대로 사용했다. 인원, 전체 스폰 예산/가중치, 5분 보스, 승리/영구보상/히든 규칙은 변경하지 않았다.

## 실제 비교 결과

공식 Godot `4.6.stable.official.89cea1439`, Mac Apple M3, OpenGL4.1 Metal/Compatibility. 이 설치 엔진은 현행 `.github/workflows/verify.yml`의4.6.stable과 같다. 일부 v41 문서에 기록된4.6.3 엔진 검증으로 주장하지 않는다.

| 동일 입력10초 fixture | ZONE 기존960 | LAMP 후보960 | ZONE 기존1280 | LAMP 후보1280 |
|---|---:|---:|---:|---:|
| 역할의 공격 시도 |2|3|2|3|
| 역할의 발사/장판 생성 |2|0|2|0|
| 직접 관찰한 예고 취소* |0|2|0|2|
| 이동 거리(월드 단위) |1192.8|1180.9|1192.0|1184.6|
| 최종 HP |71|90|71|80|
| 처치/화폐 |2/3|2/3|2/3|2/3|

*살아 있는 적에서 `warning>0→0`과 체력 감소를 같은 physics 표본으로 확인한 횟수다. 마지막 사망 프레임은 해당 적 참조가 제거돼 취소 횟수에 더하지 않았다. 기존 `TrainingEnemy.take_hit()`가 예고를 취소한다. 후보를 발사시키려고 동행·장비·AI·체력·위치·입력 정책을 바꾸지 않았다. 제시된 HP 차이는 단일 자동 입력 표본이고 난도/밸런스 수용이나 사람의 선호가 아니다.

두 화면은 같은 시작 위치·카메라·입력 시점의 실제960 렌더다. 기존 청록 장판은 플레이어 주변 원을, 후보 금빛 등불은 직선 사격 예고를 표시한다. 경사로 양쪽 수비대와 주인공이 보이고 예고가 구조물에 가려지지 않았다. 하지만 기존 자동 동행이 예고를 취소하여 후보 발사/이동 사격 대응이 실제로 추가되었다는 근거는 없다. 부모가 **기본 미채택**으로 결정했다.

- [기존 장판 입구 화면](baseline-entrance.png)
- [후보 등불 입구 화면](candidate-entrance.png)

입구/강변 쉼터/끊어진 다리/관문 여섯 지점은 양방향 내비게이션과 기존 clearance를 확인했다. 실제 동일 입력은 하강→강변 측면 접근→전투→연결 비탈 쪽 이동까지 약1.2k를 걸었다. 마지막 왼쪽 고정 입력은 두 배치 모두 기존 연결 비탈 경계에서 멈췄다. 전체 맵 왕복을 실제 걸었다고 주장하지 않는다. 새 지형/충돌 변경이 없고, 기존 정글 검사도 왕복/보스/히든/보상 규칙을 통과했다.

## fixture와 실제 검사

정상 시간 배율1.0, 동일60Hz tick의 방향/공격 action, seed4102, 기본 신규 HP/장비/동행이다. 입구에 한 번 teleport하고 주변 무작위 스폰·성장 모달·검사 창의 focus-loss 일시정지만 동일하게 분리했다. 수비대 진입 트리거, 스폰 예고/clearance, 적 AI, 동행, 공격/피격/예고, 카메라/렌더는 실제 코드다. 자연 한 판·사람 입력·오디오·성능 시험이 아니다.

- 새 검사: 배치 한 명/총보상/스폰수/왕복/다른 입구 중복 금지/crest 1회, **50개 확인,0실패**. 최종 tests 위치에서 standalone과 선택 장착 두 경로 각각50개를 재확인했다.
- 관련 기존5개와 새 검사 총6개 script: 새 배치 검사, `verify_jungle_pass`, `verify_jungle_section`, `verify_jungle_warden`, `verify_growth_rewards`, `verify_encounter_variation` 모두 통과. 전체 합본 회귀는 통합 담당자가 수행한다.
- 최종 실제 렌더4개(두 배치×두 해상도) 완료. 정확한 원시 값은 각 JSON, 실행 성공/저장 보호는 `verification.json`, 집중 검사 출력은 TXT에 있다.
- 일반 프로필/성장/설정 슬롯의 바이트·부재 및 원본 game/프로젝트 해시를 전후 대조하여 보존했다. 각 실행은 고유 `LoopConquestMapTrials/<UUID>` 저장 경로의 별도 프로젝트 복사본이다. HOME을 변경하지 않았다.

최초 standalone 조사 때 씬에 script를 재대입하면서 자원 해제 경고가 생겨 fixture를 직접 생성하도록 고쳤다. 최초 capture는 제거된 적 참조를 읽는 도구 오류로 중단했다. v2의1280 기존 배치는 focus-loss로 멈춰 무효였다. 원본은 lane 작업 폴더에 보존했고 `verification.json`에 제외 결과를 기록했다. final v3는 유효 입력/시뮬레이션으로 같은 정책을 양쪽 해상도에 적용했다. 후보 발사0은 도구 성공 조건을 억지로 만족시키려고 바꾸지 않고 실제 결과로 보존했다.

## 통합 인계와 재현

`tests/jungle_river_sentries.gd`는 검사 전용 데이터/helper다. `tests/jungle_river_fixture.gd`는 현행 jungle 스크립트의 독립 검사 mount다. **제품의 `game/jungle_pass.gd`와 공유 hybrid/hub에는 diff가 없다.** 이번 합본에는 장착하지 않는다.

`patches/jungle-river-sentry-mount.patch`는 재현용 **미적용/미채택** 선택 patch다. 기본값false이고 `-- --jungle-river-trial`일 때만 후보를 고른다. 제품 장착 지시가 아니다. 통합 담당자는 common DEV_STATUS에 아래 fragment의 결과만 반영하면 된다.

이 Mac에서 재현:

```sh
python3 scripts/check_jungle_river_sentries.py \
  --godot /Users/lty/Documents/Codex/2026-09-19/new-chat-5/work/runtime/Godot.app/Contents/MacOS/Godot \
  --output /tmp/jungle-river-recheck-NEW \
  --render
```

출력 폴더는 새 경로여야 한다. Mac의 고유 검사 저장 폴더 생성 권한이 필요하다. 일반 source/저장 해시가 달라지면 runner는 실패한다. CI의 일반 `verify_*.gd` 경로는 선택 patch 없이 독립 fixture에서 검증할 수 있다.

**진행 대시보드:** Stage3/B·C 부분 통합 / 맵 lane의 수비대 비교·안전 확인 완료, 경로차이 기존 유지·교체 미채택 / 다음은 기존v41+UI+안정성 합본의 통합 담당 회귀와 단일Mac앱 제출 / 사람 재미·미감·자연 전체 판·오디오·장시간·D 첫 지역 완료 미검증.
