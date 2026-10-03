## 기존 정글 동선과 원본 불투명 환경 — Mac map lane

- 현재 단계·세부 위치: Stage3/B 기존 사원·정글 표현 통합, 정글 능선→강변→관문 한 구간. 첫 지역 전체 완성 및 맵 볼륨 수용은 아직 아님.
- 이번까지 완료: 사원/수로의 전체 alpha·상부/지붕 제거를 비활성화하고 original material/mesh/shadow/visibility 유지. 기존 강변 안에서 물가/북측 잔해/관문 조망의 같은 석재·식생을 한 차례 재군집, 실제 수면과 동일 obstacle/tree 충돌 record 유지. 기존 지도 면적·고도·ramp·스폰·역할·보상·히든 계약 보존. rejected ZONE→LAMP 대체 재도입 없음.
- 검증: 설치 Mac Godot4.6.stable의 관련12script, 분리 patch로 격리 복사 재현, baseline/candidate × 두 해상도 ×11실제 입력 경유지 및 opaque native 렌더 PASS. 실제80→480고도/Zone 예고·장판 유지, 일반 저장/source guard 보존. 거리 약2~2.5% 변화는 완료 판정 근거 아님.
- 바로 다음 작업: 공유 파일 소유자가 두 mount patch와 공통 문구를 최신4분 타이머/적·카드·성장/보스 수정 합본에 통합하고 전체 회귀·대표 Mac 화면 확인. 이 lane에서 추가 범위 확장 반복 없음.
- 사용자 확인·미검증: 사람의 이름 없는 장소 구분·전투 가독성·재미·미감·맵 전체 볼륨, C 경제/빌드 수용, D 사원+정글 완성, Stage4 캠페인/오디오/장시간/배포 수용은 남음. 이 snapshot은6dbe4b3e의 이전5분HUD이며 최신 합본 타이머를 바꾸지 않음.
