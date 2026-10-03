# 사원 회랑 입구 군집 — 첫960 판단 화면

부모가 위치와 세 높이 군집을 승인한 뒤 만든 첫 형상 후보다. 아직 아트 채택·production 장착·전투 회귀를 하지 않았다. [정상 카메라960 화면](06-cloister-960.png)을 먼저 판단한다. 실제 화면에서 식생/새 낮은 석재는 오른쪽에 보이지만 높은 전경 중정 가장자리가 큰 파손 면 일부를 가린다. 다음 변경은 부모의 이 화면 판단 뒤에만 진행한다.

현재 단계·위치: 첫 권역 사원 / 중정 서쪽 출구→회랑 남쪽면. 이번 완료: 새 군집 helper와 원래조명 native960 1지점. 다음: 부모의 형상·군집 판단. 사람 미감·재미와 live960/1280전투, 장시간 비용 미검증.

- 기준 production `1aac501f097ff565f5fd249b9411ab91e64b3223`, 원격 noru358/new-game. 이전 재질 실험과 별개 clone/branch `codex/temple-entry-cluster-oct03`.
- Native tested code SHA `0fdea763b54b2f2cd36ae849057f474838b175f9`. 원격 후기 커밋은 이 근거만 추가한다.
- 최소 headless는 커밋 전 실행되어 receipt의 source_commit이 base를 가리킨다. 모든 실제 source_hashes가 native0fdea76 receipt와 동일함을 비교 확인했다. 34국소검사 실패0, 설치CPU138.37ms. 이 숫자는 아트 수용 증거가 아니다.
- source game/project 보존 true, 새 UUID userdata, 공식 Godot4.6.stable.official.89cea1439/M3 Compatibility. 사용자 창·앱·저장 조작 없음. GUI와 본인 headless 프로세스0 확인 후 슬롯 반환.

## 구현 범위

`game/temple_entry_cluster.gd` 단일 helper는 기존 회랑 hall의 남쪽200 구간만 원본 stone/growth batch에서 clip한다. 바깥 면은 원본색·노말을 유지한다. 원래 shaded StandardMaterial3D를 그대로 참조하며 Environment/태양/terrain 재질을 수정하지 않는다. 추가3batch: 닳은 넓은 면의 낮은 난간, 높이102/87/64 파손 석재3개와 작은 기단; 낮은 풀14/넓은 곡면잎44/뒤덩굴78의 한 돌 밑 군집; 낮은 흙·이끼·불규칙 이음 접점. raster·alpha·이미지 overlay 없음.

기존 hall footprint `(1730,1190,420,500)`의 남쪽 `(1730,1490,420,200)` 안에서 석재와 식생을 교체한다. 일부가 기존120높이 중정 단과 겹치므로 주요 형상을 서쪽에 모았다. terrain/물/충돌/보행/카메라/hidden/캐릭터/시간/경제 계약을 수정하지 않았다. 중앙 포장도 유지한다. shared scene은 건드리지 않고 [mount patch](../../patches/temple-entry-cluster-mount.patch)만 반환한다.

흙/이끼는 같은 평면의 인접 triangle을 쓰고 겹치는 planar decal을 쌓지 않는다. 바닥 접점 lift0.79–0.845, 낮은 seam stone과 soil 사이0.055, 기존 배우 그림자 base1.2 아래0.355 이상이다. native 정지1장 확인만으로 이동 중 공면 flicker가 없다고 확정하지 않는다.

## 첫 native 근거

- 실제 입력으로 입구→중정(2450,2100)→서쪽계단(1650,2275)→(1590,1840), 도달(1585.494,1840.141), active12.95초. teleport 없음. camera size9/원래 follow.
- 실제 player/적/공격예고 differential: same-FX 배우99.6829%, 적100%,예고100%. raw 배우94.3%는 제거한 예고와 발의 원래중첩도 포함하는 다른reference이며 함께 report에 보존했다.
- draw112/primitives29425. 이 자리의 동일 baseline은 아직 찍지 않았으므로 성능 개선·악화를 산정하지 않는다. 추가 geometry: stone1080/growth6363/ground468 vertices,3surface. 보관한 원래mesh와 clipping의 메모리/시간 비용 미측정.
- 샘플 압력/시계는 practice fixture에서 고정하고 실제 적 예고를 멈춘 채 보여준다. 보행·카메라·기하가림 증거이며 live 전투·난도·미감·재미 증거가 아니다.
- 첫 parser 실패와 풀0.625 범위초과 실패는 별도 로컬폴더에 보존했고 성공에 포함하지 않았다.

## 실행

```sh
python3 scripts/launch_temple_entry_cluster.py verify --godot /path/to/official/Godot --destination /fresh/check
python3 scripts/launch_temple_entry_cluster.py walk --godot /path/to/official/Godot --destination /fresh/960 --native-slot-granted
```

GUI slot이 있는 때만 native를 실행한다. `--baseline`은 군집을 설치하지 않으며 원래 화면 비교용이다. native 후보1장/4개의 actor tell reference와 [report.json](report.json)/receipt를 보존했다. 부모 판단 전에 전체 렌더 반복이나 수치 미세 조정하지 않는다.
