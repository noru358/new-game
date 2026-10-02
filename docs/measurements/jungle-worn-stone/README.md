# 정글 관문 대표 석재 샘플 — Mac 검증 완료

**결과:** 정글 관문 접근 한 묶음의 석주 8개와 바위 10개만 교체했다. 석주는 쌓은 층·모따기·마모된 상단으로 건축의 규칙성을 남기고, 바위는 비대칭 어깨·깊이·넓은 면으로 자연 침식을 대비한다. 기존 석계단 12개 표면 마디는 끝이 닳은 형태로 바꾸되 실제 연속 경사를 따라간다. 전체 맵 확장, 새 엔진 기술, 이미지 생성은 없다.

## 전달·장착

- 기준: local v42 `f21f2b63e600c0a27233bbef87d4cc96bb9643dc`. 통합 담당이 확인한 당시 원격 current-playtest는 v41 `93674fdb`; 혼동하지 않는다.
- 소유 코드: `game/jungle_worn_stone_visuals.gd` 및 UID.
- 공유 장착: `patches/jungle-worn-stone-mount.patch`. `game/jungle_pass.gd`의 18개 기존 노드 메시를 교체하고 `game/hybrid_height.gd`의 `_gate_stairs` 표면만 helper에 연결한다. 이 lane은 공유 파일을 커밋하지 않았다.
- 아트 helper/자료 커밋을 먼저 가져온 뒤 `git apply --check patches/jungle-worn-stone-mount.patch`와 적용을 통합 담당이 수행한다. actor/depth 수정과의 최종 합본 회귀는 통합 담당 소유다.
- `--worn-stone-baseline`은 기존 BoxMesh와 계단 평면/선으로 돌아가는 비교 스위치다. 현행 route/terrain/actor/세이브 정책은 같다.
- 소스 근거: MASTER §3 장소 경험 제작, §6 동남아 정글, `jungle_pass_terrain.gd` ramps[3], `jungle_pass.gd` `_build_gate_approaches`, `hybrid_height.gd` `_gate_stairs`.

## 검증 및 비용

Godot 4.6 공식 Mac / Apple M3 / OpenGL 4.1 Compatibility에서 960×540·1280×720의 기준/후보 네 실행이 통과했다. 실제 방향키·공격 입력으로 석계단과 바위길을 이동했고 적 AI/예고/피격이 실행됐다. 표본은 두 시작 배치, 적2개(관찰용 HP), 자연 지형·navigation·충돌, ambient spawn 및 성장 modal 억제로 구성한다. 자유로운 사람 플레이나 자연 한 판의 난이도 표본이 아니다.

- 기존 정글 pass, route, terrain coherence, surface overlap 네 회귀 PASS.
- 18개 노드의 transform/material, 노드/표면 수18→18 보존. 모든 석재 꼭짓점이 원래 local BoxMesh 경계 안이다. 새로운 CollisionObject/Shape/지형 레코드/발판 높이를 만들지 않는다.
- 계단 장식은 각 꼭짓점의 기존 `ramp_height`에0.35~2.0px만 더한다. 이전 어두운 선은3.5px였다. 새로운 수평 디딤판이나 튀어나온 단차가 없다.
- 모든 terrain/collision 레코드 build 전후 동일. 일반 저장·게임 소스 SHA-256 보존 검사를 각 실행에서 통과했다. 실제 배포 앱을 덮어쓰거나 실행하지 않았다.

| 지표 | 기준 | 후보 | 차이 |
|---|---:|---:|---:|
| 장식 노드/mesh surface | 18 / 18 | 18 / 18 | 0 |
| 장식 삼각형 | 216 | 1304 | +1088 |
| 전체 terrain 삼각형 | 7752 | 7728 | −24 |
| 전체 순수 geometry 차이 | — | — | **+1064 삼각형** |
| 960 정적 석계단 drawcall | 215 | 215 | 0 |
| 960 정적 바위길 drawcall | 221 | 221 | 0 |
| 1280 정적 석계단 drawcall | 218 | 218 | 0 |
| 1280 정적 바위길 drawcall | 224 | 224 | 0 |

같은 정지 좌표의 render object도394/400으로 동일했다. 정적 프레임 primitive 수는14809→15713(계단),31833→32705(바위)로 증가했다. 그림자·시야가 포함되는 엔진 카운터와 전체 geometry 삼각형을 구분한다. 이동/전투 순간의 drawcall은 타격 효과 때문에 변동하므로 비용 비교는 별도 정지 표본을 썼다. 장시간 FPS/최저 사양 검증은 아니다.

## 화면과 재실행

`comparison.html`을 열면 동일 960/1280 시야의 원본 PNG를 비교할 수 있다. 대표 두 장은 `jungle-worn-stone-before-1280.png`, `jungle-worn-stone-after-1280.png`다. 작은 석재 외의 큰 사각 절벽/벽/포장은 유지한다. 모든 사각 형태를 없애는 요청으로 범위를 넓히지 않는다.

```sh
python3 scripts/check_worn_stone_sample.py --godot /ABS/Godot.app/Contents/MacOS/Godot --output /ABS/NEW-DIRECTORY --phase import
python3 scripts/check_worn_stone_sample.py --godot /ABS/Godot.app/Contents/MacOS/Godot --output /ABS/NEW-DIRECTORY --phase regression
# 다음 phase를 각각 같은 output에서 실행: baseline-960, candidate-960, baseline-1280, candidate-1280
```

Mac Godot 경로: `/Users/lty/Documents/Codex/2026-09-19/new-chat-5/work/runtime/Godot.app/Contents/MacOS/Godot`. 실제 QA 복사본: `/Users/lty/Documents/Codex/2026-10-03/task/qa-worn-stone/project`. 스크립트는 원본을 복사하고 mount patch를 그 복사본에만 적용하며 `LoopConquestMapTrials/worn-<UUID>` 격리 userdata를 요구한다. 창은 화면 밖에서 렌더한다. Python3.9 이상으로 실행 가능하다. 최초 import에서 sandbox 밖 editor settings 저장은 차단됐으며 게임 파싱/네이티브 검사에 실패가 없다.

**미검증:** 사람의 미감·전투 가독성 선호, 장시간 성능, 통합 담당의 actor/depth 수정과 합본 회귀. 기존 몹 매몰은 이 아트 lane의 해결 주장이 아니다. 아트 변경은 기존 외곽과 높이를 늘리지 않는다.
