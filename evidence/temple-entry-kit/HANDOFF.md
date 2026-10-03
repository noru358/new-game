# 사원 대표 입구 구현 기반 인계

현재 단계는 첫 권역 대표 아트의 사원 중정→서쪽 회랑 입구다. 부모가 전체 GALLERY_HALL 장식 교체 화면을 대표 군집의 구현 기반으로 채택했다. 최종 아트 승인이 아니다. 두 큰 기둥의 상자형 인상과 전체 밀도는 아직 남으며, 추가 미세 조형은 중단했다.

## 소스와 장착

- 독립 브랜치: `codex/temple-entry-kit-oct03`, 저장소 `noru358/new-game`.
- 출발 production: `1aac501f097ff565f5fd249b9411ab91e64b3223`. canonical `686228f1d2f7cad0f09311c2006f46c6c16ce9d3`가 그 조상임을 확인했다. main을 기준으로 삼지 않았다.
- 게임 helper는 채택 화면의 `1549d377e979016a304c1cd815699ffd4b2a4116`과 바이트 단위로 같다. 이 브랜치의 게임 코드 및 최종 계약/headless 전투 검사 SHA는 `09ed5314b1ab1f211b2e2abc6eee0bdc12f58f76`다. 이후 인계 문서와 증거 커밋은 게임 실행 버전 변경이 아니다.
- 소유 파일은 `game/temple_entry_cluster.gd`, 전용 `tests/*temple_entry*.gd`, `scripts/launch_temple_entry_cluster.py`다. 공유 장착은 `patches/temple-entry-cluster-mount.patch`, 상태판은 `patches/temple-entry-cluster-status.patch`로 반환한다. 두 patch 모두 check만 실행했다. 공유 씬과 DEV_STATUS는 부모가 통합한다.
- 실제 바닥/벽/계단 지형과 충돌, 120높이의 남동쪽 plateau, 중정과 계단 포장, 카메라/캐릭터/hidden/저장/경제/240초 계약을 보존했다. 본선 외 다른 사원 씬에는 helper를 설치하지 않는다.

현재 석재/식생 장식은 기존 StandardMaterial3D의 음영을 사용하는 3D 메시다. 기존 재질이 모두 unshaded라는 가정은 사용하지 않았다. 설치는 기존 석재·식생 배치에서 Rect2(1730,1190,420,500)의 회랑 장식 전체를 제거하고 낮은 턱, 뒤쪽 파손 기둥 둘, 넓게 쓰러진 석재, 크기가 다른 식생과 낮은 접점을 3배치로 만든다. 조명과 실제 terrain mesh는 유지한다. 자동 투명화나 정지 이미지 덧씌우기를 사용하지 않는다.

가장 큰 두 병목은 기존 연속 회랑 전경이 입구 군집을 가렸던 구조와, 현재 카메라에서 큰 건축과 중간 식생의 규모·층을 동시에 읽히게 하는 제한이다. 부분 군집을 작은 틈에 넣는 방식은 앞선 두 화면에서 미채택됐다. 이번 전체 장식 교체는 입구에서 군집을 드러내지만 벽 근접 Body 가림까지 해결하지는 못했다.

## 실제 검사와 실패

Mac 공식 Godot `4.6.stable.official.89cea1439`, 원래 Compatibility 렌더러를 사용했다. 모든 실행은 새 프로젝트 복사본과 별도 UUID userdata였다. 원본 프로젝트 hash가 실행 전후 같았으며 사용자 앱/저장/checkout을 건드리지 않았다. headless는 직렬 한 개, GUI는 허가된 슬롯에서 한 개만 사용했다. 인계 시 소유 엔진은 모두 종료했다.

| 검사 | 실제 tested SHA | 결과 |
|---|---|---|
| 최종 계약/terrain/조명 identity/경로/접점 | `09ed5314b1ab1f211b2e2abc6eee0bdc12f58f76` | 38검사, 오류0 |
| production→kit 국소 중심 광선 | `b651b04aff22745f75fc17f631ceb088a4e8c89d` | 132광선, 기존 가림8→후보1, 새 가림0 |
| 960/1280 native 정상입력 보행 전후 | `a7489960a2f07716ab3bae81348826c46e6d1b38` | 전후 각 33초, 6지점·30원시 PNG; 기준 exit1/실패4, 후보 exit1/실패2 |
| 기존 장식의 native 실제 AI 전투 | `09ed5314b1ab1f211b2e2abc6eee0bdc12f58f76` + baseline flag | 960/1280 각각 10.983초, PASS |
| 후보 headless 실제 AI 전투 | `09ed5314b1ab1f211b2e2abc6eee0bdc12f58f76` | 각각 10.983초, 공격490/496프레임·실제 예고183/164프레임, PASS |

native 보행은 중정→기존 서쪽 계단→입구→벽 근접→회랑을 정상 입력으로 이동했다. 전투 압력/시간은 고정하고 실제 적 Body/예고를 같은 위치에 고정했다. 실제 AI 전투 검사는 별도이며, 진입부 합성 시작점과 두 80HP 적, 동일한 주변 스폰/성장창/wisp 억제 조건이다. headless 후보의 프레임 간격과 이동거리는 native 기준의 GPU 성능이나 전투 결과 비교에 사용하지 않는다. 후보의 native 실제 AI 전투는 GUI 0 지시로 미실행이다.

가림 비율은 **같은 배우·FX를 유지한 scenery-hidden 참조**에 대한 차등 Body/예고 픽셀이다. Body만 남긴 별도 참조는 적/예고의 겹침도 포함하므로 아래 scenery 판정과 혼동하지 않는다.

| 벽 근접 실제 도달점 (1694.0873,1309.3553) | 기존 Body | 후보 Body | 기존 예고 | 후보 예고 |
|---|---:|---:|---:|---:|
| 960×540 | 61.27% | **86.33% 실패** | 90.26% 실패 | 99.74% |
| 1280×720 | 61.24% | **85.16% 실패** | 90.68% 실패 | 99.71% |

Body의 98% 기준 실패는 기존에도 있었고 후보에서 줄었다. 예고는 후보에서 95% 기준을 통과했다. 후보의 남은 두 Body 실패를 성공으로 집계하지 않는다. 입구/회랑의 Body는 전후 99.60~99.87%, 후보 적 Body는 모든 지점 98.48~99.22%였다.

남은 가림의 메시 소유자는 같은 native 도달점에서 headless billboard 표면 진단으로 확인했다. 불투명 texture 표본176개 중 기존 `WeatheredCourtyardWalls`가57개를 가렸다. 후보는 `BrokenMasonry`17개와 `ShelteredGrowth`1개였다. 석재 hit의 x1773.47~1796.53, z1372.93~1392는 첫 파손 기둥 Rect2(1770,1280,117,112), top109의 윗면/끝이다. 새로 막힌 표본0·풀린 표본39지만, 이는 제한된 표면 광선이며 전체 Sprite 픽셀의 무회귀를 증명하지 않는다. **기존 기준 실패를 완화했으나 잔여 가림은 새 기둥/식생이 만든다.** 추가 기둥 미세 수정은 부모의 방향 판단에 맡긴다.

960 동일 화면 통계는 입구 draw calls109→112, primitives31024→22421, 벽 근접111→114/31048→22445였다. 1280도 draw calls+3, primitives−8603이었다. 전체 회랑 장식 제거가 포함된 수치이며 지속 GPU 성능 개선을 입증하지 않는다. 최종 설치 비용과 자세한 원시 수치는 `summary.json`에 기록했다.

이전 shadow 검사의 중심1.2 비교는 실제 아랫면을 증명하지 못했다. 보존된 최종 검사는 CylinderMesh 실제 아랫면0.8 game units를 계산하고 contact 최고0.725 < 0.8−margin0.05, 실제 floor와 최소0.17 분리를 확인한다. 이 수정과 기존 원시 실패 기록을 지우지 않았다.

## 핵심 전후 화면

PNG는 엔진의 실제 native drawable이며 리사이즈하지 않았다. 같은 tested SHA/입력/배우 조건의 baseline flag 전후다. 카메라9와 원래 follow를 유지했다.

| 구간 | 기존 | 후보 |
|---|---|---|
| 입구 960 | [before](entry-960-before.png) | [after](entry-960-after.png) |
| 입구 1280 | [before](entry-1280-before.png) | [after](entry-1280-after.png) |
| 회랑 960 | [before](cloister-960-before.png) | [after](cloister-960-after.png) |
| 벽 근접 실패 960 | [before](wall-shoulder-960-before.png) | [after](wall-shoulder-960-after.png) |

공개 브랜치에는 이 8핵심 PNG와 요약만 추가했다. 원시 로그/60보행 PNG/전투 참조/상세 Body hit는 Mac task workspace의 `kit-*` 폴더에 보존한다. 사용자의 Library 참고 이미지는 실제 픽셀을 열람했고 공개 저장소에 포함하지 않았다.

## 실행과 다음 검사

장착 patch를 부모의 통합 복사본에 적용하면 현재 정상 게임 이동/전투/카메라에 연결된다. 독립 검사는 다음과 같이 실행한다. destination은 매번 새 경로여야 한다.

```sh
python3 scripts/launch_temple_entry_cluster.py verify --godot /path/to/official/Godot --destination /fresh/verify
python3 scripts/launch_temple_entry_cluster.py impact --godot /path/to/official/Godot --destination /fresh/impact
python3 scripts/launch_temple_entry_cluster.py combat --godot /path/to/official/Godot --destination /fresh/headless --entry-only --measure-only
```

부모가 GUI 슬롯을 배정한 뒤만 `combat ... --entry-only --native-slot-granted`로 후보 960/1280 native 전투를 실행한다. 전후 정상입력 촬영은 `walk ... --all-sizes --native-slot-granted`, 기준은 추가 `--baseline`이다. 두 벽 근접 실패 때문에 walk의 exit1이 예상된다. 이를 무시하거나 PASS로 바꾸지 않는다.

바로 다음 작업은 후보 native 전투, 부모의 residual pillar 판단과 공유 mount 통합이다. 사람의 미감·장소감·재미, 자연 진행 완주, 장시간 성능/소리는 미검증이다. merge/shared branch/package는 제작하지 않았다.
