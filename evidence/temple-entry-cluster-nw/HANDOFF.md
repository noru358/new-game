# 사원 북서면 이동 — 대표 군집 목표 미달

[실제 960 회랑 진입 화면](06-cloister-960.png). 부모가 승인한 북서면 이동을 한 번 시험했다. 큰 파손 석재 한 면은 드러났지만 중간 잎과 낮은 접점은 앞에 남은 회랑 석조에 묻히며 화면 오른쪽의 제한된 부분을 차지한다. 열린 중정→좁은 폐허 회랑의 경험 차이를 충분히 만들었다고 판단하지 않는다. 같은 구간의 재이동·잎 수/크기 미세 조정은 중단했다. 아트 채택 전 960/1280 live 전투 회귀도 실행하지 않았다.

현재 단계·위치: 첫 권역 / 사원 중정→회랑 입구. 이번 완료: 승인된 국소 북서면 이동과 1개 native 판단 화면. 다음: 부모가 남은 회랑 전경 형상/통로폭과 군집 위치를 함께 판단. 사용자 미감·장소감·재미와 live 전투·장시간 비용은 미검증.

## 실제 소스와 변화

- production `1aac501f097ff565f5fd249b9411ab91e64b3223`의 원래 조명/재질. 이전 shader 실험 미적용. 실제 remote noru358/new-game, branch `codex/temple-entry-cluster-oct03`.
- Native tested code SHA **`64f1510b73b13289bc16f7b367f336475c61833f`**. 후기 커밋은 근거와 상태 patch만 추가한다. 최소 headless는 commit 전에 실행했으나 모든 source_hashes가 native receipt와 일치한다.
- 군집의 형태·잎 수·높이는 처음과 동일. 군집 root를 z−240으로 옮기고 기존 batch의 교체영역을 `(1730–2150,1250–1450)`으로 바꿨다. 첫 실패안의 남쪽 `(1490–1690)`은 원래 masonry다. 새 거대건축·카메라·terrain·collider·물·캐릭터·hidden·적 스폰·저장·경제 변경 없음.
- 전경 중정 단을 낮추는 대안은 120 높이 top 보행면/height_at/edge barrier/ramp/paving까지 함께 수정해야 하므로 이번 최소안에서 제외했다. 단순 wall visual만 낮춰서 보이지 않는 높이 120 바닥을 만드는 방식은 사용하지 않았다.

## 좌표와 근거의 차이

첫안 사진은 `(1590,1840)`에 도달했고 이번은 같은 원래 북진경로를 지나 **`(1450,1700)`**에서 찍었다. 실제 도달 `(1453.014,1703.671)`. camera size 9, offset/각도/normal follow는 그대로이며 줌이나 군집을 위한 카메라 회전/teleport는 없다. 이전과 같은 좌표의 직접 전후사진이 아니므로 시야차이를 순수 asset 효과로 읽지 않는다. [첫안](../temple-entry-cluster-first/06-cloister-960.png)도 보존한다.

입구→중정→서쪽계단→이전 지점→회랑 진입의 정상입력 active 13.6833초. 시간/스폰 압력을 고정한 visual fixture이며 실제 적 Body/공격예고는 정지시켜 표시했다. 보행/동선/가림의 근거이지 live AI 전투나 장소 수용 증거가 아니다. same-FX player 99.0625%, 적 100%, tell 100%. raw player 94.3452%는 기존 예고가 발과 겹치는 다른 reference까지 포함하며 지우지 않았다. errors 0. draw 112/primitives 30569는 한 위치 자료이며 이전 사진과 카메라 위치가 달라 성능 전후로 비교하지 않는다.

국소 검사 34조건 실패 0. 기존 barrier 안 world bounds, terrain/환경/카메라/속도/240초/hidden 계약과 기존 normal route 확인. 설치 CPU 137.37ms. vertex stone 1080/growth 6363/ground 468과 3batch는 그대로이며 원본 mesh 보관/clip의 메모리·장시간 비용은 측정하지 않았다. 숫자 PASS를 아트 성공으로 사용하지 않는다.

## 앞선 그림자 검사 정정

첫안 검사는 그림자 중심 1.2 map-unit과 바닥 0.845를 비교했으나 실제 CylinderMesh 아랫면은 **0.8**이다. 따라서 앞선 검사는 아랫면 여유를 입증하지 못했다. 원시 receipt/로그/그림은 역사 근거로 남긴다. 이번에는 contact 0.67–0.725로 낮추고 실제 mesh 아랫면 0.8에서 0.05의 추가 margin을 뺀 값보다 낮음을 확인한다. 이 정합 수정은 잎/돌의 미세 아트 조정이 아니다.

흙과 이끼는 인접 triangle의 한 평면, seam stone은 0.055 더 높다. 모든 contact가 0.85 상한과 실제 shadow 아랫면 아래다. 정지한 1장으로 이동 중 공면 flicker/전체 가림을 보장하지 않는다. 실제 픽셀에서 낮은 접점은 여전히 잘 읽히지 않는다.

## 인계와 중단 범위

[Mount patch](../../patches/temple-entry-cluster-mount.patch)는 공유 씬에 미적용이다. [상태 patch](../../patches/temple-entry-cluster-status.patch)는 부모가 공유 DEV_STATUS에 반영할 제안이다. production 자동 장착·merge·패키지 없음. 사용자 Library 참고 이미지는 private consumer Mac에만 있고 이 저장소에 없다. source game/project 보존 true, fresh UUID userdata, 공식 4.6.stable.official.89cea1439/M3 Compatibility.

이 native 종료 후 본 task GUI/headless Godot 0 확인, 슬롯을 반환했다. 이번 북서면 이동을 마지막 국소 위치 실험으로 유지하고, 부모가 국소 입구 구성을 판단하기 전 추가 렌더/9601280 전투/숨은 장식 완료 선언을 하지 않는다.
