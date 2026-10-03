# 부모 통합 인계 — W_FLOW 재배치 연계 후보

현재 단계·위치: 첫 권역 반복 빌드 행동(Stage3/C). 부모가 승인한 한 후보이며 첫 권역 완성/재미 수용이 아니다.

## 소스와 소유

- 실제 GitHub clone/fetch 및 PR52/51 확인. 기준 `a141b6cbe96c5143b23fefdaf9c809a90d3d3ae1`, 전달/canonical `bad54d2cb650702306ebbfc56b7df5efb8a94c6d`의 자손(0/9). 문서 전용 `e860cb6` 후속도 읽었으며 작업을 재시작하지 않았다. 오래된 main은 사용하지 않았다.
- 전용 branch `codex/combat-growth-actions-v48`. 실제 엔진 `4.6.stable.official.89cea1439`(Mac 공식 Godot4.6, 4.6.3이 아님).
- 수정한 제품 파일은 배정받은 `game/player.gd` 하나. shared hybrid_region/hub/run_profile/terrain/프로젝트 설정/기존 문서는 수정하지 않았다.
- `flow-weave-mount.patch`는 부모가 적용할 mount다. `_finish_run`의 `player.clear_flow_weave()` 1줄은 생애주기 검사에 적용해 통과했다. 허브의 W_FLOW ‘다음 적중 평타/빗나가면 유지’ 문구는 제안이며 렌더 미검증이다.

## 병목과 단일 후보

기존 W_FLOW는 베기 적중으로 얻은 준비를 다음 평타 시작 때 소비한다. 베기로 표적을 통과한 뒤 앞쪽의 빈 평타 한 번을 치면, 뒤로 재배치하여 맞힌 평타에 강화/환급이 없다. 코드 오류로 단정하지 않고 조작 설계의 손실로 보고했다.

부모 승인 후보: 빈 평타에서는 준비를 유지하고, 살아 있는 대상에 실제 피해를 준 첫 평타 동작에서 소비한다. 그 동작의 모든 적에게 +25%, 재사용 환급0.22초(옵션 보너스 포함)는 한 번만 적용한다. 무효/죽은 대상은 소비·환급·RIPPLE 파동을 일으키지 않는다. 기존 재도전/새 플레이어/퇴장 reset을 보존했다. 새 카드/중첩/타이머/저장/수치 튜닝은 없다.

대안은 기존 소비 계약을 유지하고 베기 후 빈 평타를 피하도록 요구하는 것이다. 구현 비용은 player의 소비/유효피해 두 지점과 reset helper, 부모 finish mount1줄, 독립 검사다. 가격/XP/밀도/보스HP/대시/영구10종5등급은 그대로다. choice_batch/late_xp/cap은 켜지 않았다. 이미 통합된 소수점/ORBIT/CHAIN 문구를 재구현하지 않았다.

## 근거

동일 짧은 입력(실제 물리60Hz/고정 생존 표적): x800에서 베기로 x1010까지 통과, 적x870 HP1000→986. 앞쪽 빈1타 후 뒤로7프레임 이동(x975), 같은2타 적중.

| 관측 | 기준 | 후보 |
|---|---:|---:|
| 빈1타 뒤 준비 | 사라짐 | 유지 |
| 재배치2타 피해 | 12 | 15 |
| 재배치2타 환급 | 없음 | 한 번, 남은 대기0 하한 |

정상속도 기존 common 정책/seed481/첫생명 한 판은 각각 한 번만 실행했다. 정책을 유리하게 재튜닝하지 않았다. prior clear/6해금/294투자는 합성 준비이며 런 중 XP/피해/회복/보스 시간을 주입하지 않았다. 두 표본은 모두 보스 첫 사망에서 재도전 가능 상태로 끝났고 **IN_PROGRESS**, 성공·정산 증거가 아니다.

| 관측 | 기준 | 후보 |
|---|---:|---:|
| 종료 active초 | 252.550 | 253.183 |
| 실제 초기9카드(구성 동일)까지 유효 강화 동작 | 15 | 20 |
| 초기9카드까지 실제 환급절감초 | 3.001 | 3.080 |
| 전체 평타 시작/유효명중 | 377/287 | 376/290 |
| 전체 유효 강화·환급 동작 | 78 | 84 |
| 전체 실제 환급절감초 | 9.391 | 9.068 |
| 유효 피해 / 과잉 피해 | 11117.980 / 2721.635 | 11528.361 / 2595.695 |
| 실제 피격량/피격횟수 | 420/35 | 431/38 |
| 이동px/대시횟수 | 83320/52 | 83244/53 |
| 카드 선택/합성 선택 체류wall초 | 27/41.216 | 28/42.748 |
| 보스 도착/교전 active초 | 214.800/242.550 | 226.967/241.200 |

후보가 빠른 완주/안전한 난도를 입증한 결과가 아니다. 후보의 비명중 강화시작22개는 같은 준비를 유지한 재시도가 포함돼 잃은 충전22개로 계산하면 안 된다. 단일 봇 사망/선택 횟수를 인간 난도·독해·재미로 해석하지 않는다. 전체 입력 경로와 선택 시간이 갈라진 수치를 단순 인과 효과로 주장하지 않는다. 가장 직접적인 인과 근거는 위 동일 짧은 입력이다.

세 빌드는 같은294투자/같은9번의 카드트리플/같은3표적/2.2초 합성 행동으로 따로 확인했다. 실제 기존 카드 선택 API와 전투 물리를 사용하되 XP/후보/표적/진행 시계는 합성했다. 서로 다른 입력 순서의 사용 증거이며 DPS/생존/선호 순위가 아니다.

| 빌드 | 관측 행동 |
|---|---|
| 집결·폭발 | 3타2회→4타2회 유효명중, 평타10시작/9명중, 이동30.75px(입력 이동 없음·피격 반동 포함) |
| 이동 연계 | 베기1→빈 평타→재배치→유효 강화1/환급1, 평타3시작/2명중, 이동370.50px. 환급은 이미0바닥이라 실제절감0초 |
| 동행 화력 | 직접 평타1명중 뒤 재배치157.34px, 기존companion_focus2초/지정표적 사격7회(전체8회) |

## 검사와 한계

- 새 회귀30검사0실패: 빈 공격 유지, 다중적25%, 한 번 환급/0하한, 반복 active프레임, 살아 있는 적 처치/과잉, dead-but-not-freed, inactive boss, 막힌 공격, RIPPLE 무효차단/유효한번, 재도전, 실제region 끝 mount/재출정/장비변경, profile 비저장, ledger 산술.
- 기존 meta_preparation, behavior_mods, gather_safety, 1g_combat_feel, companion_focus, permanent_growth_v7 통과. v7 회귀124검사. 전체CI는 수행하지 않았다.
- 각 실행은 byte-copy와 새 UUID `Codex-Combat-Actions-v48` private userdata, 한 번에 headless엔진1개였다. 일반 저장을 조회/삭제/편집하지 않았다. source game/project 해시가 모든 유효 실행 전후 일치했다. 기존 앱/창/checkout 보존.
- 첫 짧은 fixture의 InputMap/buffer 누락, 첫 새검사의 expected 타입 표기, 첫 합성 세빌드의 모달 후 공격 해제 누락은 도구 결함이었다. 원자료를 로컬에 보존하고 판단에서 제외했으며 수정 후 실제 동작 assert를 넣었다. 게임 실패를 숨기거나 정책/seed를 승리에 맞춰 조정하지 않았다.
- 실제 렌더/GUI/청취, 허브 문구960/1280 배치, 사람 재미·손맛·세빌드 선호·자연 세맵 완주는 미검증이다. 부모 합본에서 확인해야 한다. 첫 권역 최종 완성으로 보고하지 않는다.

원자료는 `evidence/summary.json`의 local_path와 SHA256으로 참조한다. 큰 raw JSON/로그는 Git에 넣지 않았다. 핵심 짧은 전후 JSON과30검사 로그만 함께 보낸다.

## 재현과 통합

공식 Godot 경로를 `--godot`으로 지정한다. 새 output이 필요하며 일반 저장 대신 새 Mac private userdata를 만든다.

```
python3 scripts/check_build_actions.py --godot /path/to/Godot --output /tmp/flow-final-new --mount-flow-end --scripts tests/verify_flow_weave_retention.gd
python3 scripts/check_build_actions.py --godot /path/to/Godot --output /tmp/build-episodes-new --mount-flow-end --matched-episodes --builds gather,movement,companion
python3 scripts/check_build_actions.py --godot /path/to/Godot --output /tmp/build-natural-new --mount-flow-end --builds movement --seed 481 --seconds 330
```

바로 다음: 부모가 이 브랜치의 commit을 제작에 통합하고 mount/허브 문구/DEV_STATUS를 최종 합본 소유권에 맞춰 적용한다. 합본 전체회귀/렌더/사용자 수용/패키징·배포는 부모 담당이다. 이 lane은 main/production/current-playtest/릴리스를 옮기지 않는다.
