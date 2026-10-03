# 회랑 벽 장식 한 구간 전체 교체 — 첫 960 아트 판단

[새 입구 면의 실제 960 화면](06-cloister-960.png). [직전 북서면 시험](../temple-entry-cluster-nw/06-cloister-960.png)과 같은 원래 경로·같은 `(1450,1700)` 지점이다. 기존 원본 석조가 새 군집 앞에 남는 제한을 없애고 한 wall 구간 전체를 폐허 입구로 교체했다. 부모가 화면 효과를 판단하기 전 아트 채택·미감·장소감·재미를 통과로 부르지 않는다. 이후 영향 회귀·1280·실제 전투는 채택 방향에서만 진행한다.

현재 단계·위치: 첫 권역 사원 / 중정에서 폐허 회랑으로 들어가는 입구. 완료: 원본 가림 장식 전체 교체와 국소 38검사·960 한 지점. 다음: 부모 아트 판단. 사용자 미감·장소감·재미·live AI 전투·1280·장시간은 미검증.

## 소스 근거와 소유 범위

원본 `temple_circuit_environment._build_court()` → `temple_place_composition.masonry()` → `temple_environment_kit._gallery_fragment()`가 `GALLERY_HALL = Rect2(1730,1190,420,500)`, height110을 장식한다. 연속 기초 42.9 위에 x축4bay, 각95폭×494길이의 상부 덩어리 69.3/79.2와 작은 top110 기둥을 얹는다. 이 기하가 `WeatheredCourtyardWalls`에 합쳐져 앞선 부분 교체를 덮었다. `HybridTerrain.barriers()`가 해당 rect 전체를 막으므로 보행 가능한 단이 아니라 기존 wall barrier 장식이다.

별도의 실제 중정 plateau는 `(1870,1600,990,1150)`, height120이다. 원본 hall과 동남쪽 280×90이 겹치지만 이 plateau/height_at/포장/ramp/edge collider는 건드리지 않는다. 이번 source는 **원본 hall 전체 `(1730–2150,1190–1690)`의 masonry와 attached growth만 제거**하며 terrain mesh와 `CourtAndStairCourses` resource identity를 유지한다. 숨은 방/캐릭터/카메라/적 스폰/240초/경제/저장 변경 없음.

새 helper의 같은 3batch에 길-facing 낮은 붕괴 난간, 뒤쪽 넓은 파손 기둥2와 낮은 큰 돌1, 깎인 작은 기단, 돌 밑 풀→중간 넓은 곡면 잎→뒤덩굴을 묶는다. 입구 한 면에 걸쳐 배치하고 앞을 덮는 기존 고층 box를 남기지 않았다. 원래 조명과 shaded StandardMaterial3D 참조를 유지한다. raster/alpha/정지 이미지 overlay/자동 투명화가 없다. 기존 곡면 잎 topology의 노말 방향을 위쪽으로 바로잡았다.

## 정확한 검증

- Base production `1aac501f097ff565f5fd249b9411ab91e64b3223`, independent branch `codex/temple-entry-cluster-oct03`, remote noru358/new-game.
- Native tested code SHA **`1549d377e979016a304c1cd815699ffd4b2a4116`**. 이후 커밋은 판단 근거만 추가한다. 이전 shader 실험 미적용.
- 최소 headless는 커밋 전에 실행했고 모든 game/project/verify script hash가 native receipt와 동일하다. 캡처 report의 과거 좌표 명칭을 바로잡은 capture script metadata만 다르다. native는 그 수정까지 포함한 위 SHA에서 실행했다.
- 국소38검사 실패0. 원본 hall ornament 내부 vertex 잔존0, terrain/paving identity, 원래 terrain 기록/normal route/hidden/camera/movement/boss-time 계약 확인. 설치 CPU204.81ms는 단일 시작 표본이다.
- 실제 입력으로 입구→중정→서쪽 계단→이전 첫 지점→회랑 진입까지 active13.6833초. 도달 `(1453.014,1703.671)`. 직전 북서면과 도달/보행시간이 동일하며 camera size9/offset/각도/normal follow를 변경하지 않았다.
- 원래 실제적 Body/공격예고를 정지시킨 visual fixture. same-FX player98.9583%, 적100%, tell100%, errors0. raw player94.2460%는 예고를 함께 제거한 reference의 기존 발 중첩도 포함하며 별도로 보존한다. 이 검사는 live AI 전투·난도·재미의 근거가 아니다.
- 동일 진입 지점에서 직전 북서면 draw112/primitives30569 → 이번 draw112/primitives22421. 실제 부모 승인 전 placeholder baseline 비교가 아니며 이것만으로 장시간 성능 향상이라 주장하지 않는다. 원본 메모리 보관/clip 비용은 별도 미측정.
- 새 vertex stone1200/growth6291/ground468,3batch. 최대 실루엣109는 원래 wall110 이하, 기존 blocked footprint 유지. contact0.67–0.725, 실제 plain floor와 최소0.17 분리, 실제 actor shadow 아랫면0.8−margin0.05 아래. 정지1장으로 전체 이동중 flicker를 보장하지 않는다.

## 인계

mount patch는 공유 씬에 미적용이다. [Mount patch](../../patches/temple-entry-cluster-mount.patch)는 부모 소유 장착용이다. production 자동 적용·merge·패키지 없음. source game/project 보존true, fresh UUID userdata, 공식 Godot4.6.stable.official.89cea1439/M3 Compatibility. native 종료 후 본인 GUI/headless0 확인하고 슬롯 반환했다.

사용자 Library 참고는 비공개 consumer Mac 파일로만 열람했고 저장소에 올리지 않았다. 이전 부분 교체·북서면 위치 실험과 실패 원시 근거는 각각 보존한다. 이번은 세번째 위치 미세 이동이 아니라 원본 가림 구조 전체 교체다. 부모 판단을 기다리며 다음 방향을 임의로 확정하지 않는다.
