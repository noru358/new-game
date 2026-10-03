## v49 hidden flow candidate — parent-owned status mount

- 첫 권역의 기존 사원 정원/정글 폭포 계곡 출입·표기 lane이다. v48 본선 디자인과 발견/각성/보상/보스240초/카드·HP·재도전 계약은 유지한다. 최종tested source는d9ead85(최초flow5cca186,문턱floor0.5mount0a644f8), 원격검증 branch codex/hidden-flow-v49. canonical/전달 앱은 부모가 관리하며 이 후보로 변경하지 않았다.
- 실제 활성layout에서 입구/도착/출구/본선복귀는30반경 안전·연결이고 idle즉시복귀가 없었다. 사원 옛main 미니맵1978.7차이, 정글내부ALTAR990차이, 사원본선단서 구좌표, 필드·거리 gate없는 exitLabel을 확인·수정한다. shared미니맵/사원terrain은부모용mountpatch이며옛사원입구를삭제하지않는다.
- 사원합법east접근의같은LEFT홀드에서frame23진입→71자동복귀를재현했다. 기존.8초와실제배우여유/새이동입력조건만으로최소재전환debounce를적용했다. release만으로전환없음/같은입력재누름의도복귀/빠른방향변경/반복양방향이동·pause/card/retry를검사했다.
- Mac4.6 공식headless의290국소검사와관련8회귀pass. 고유userdata·일회복사본으로기존앱/세이브/checkout보존. 960/1280실제AppleM3뷰포트56PNG(전후48+최종근접라벨8)/0실패를확인했다. 작은첫후보글자를기각하고28/.010의최종근접문구를두해상도에서직접검토했다. 240근접/필드/overviewgate유지. 보호한정상/preview56json바이트동일,GUI/headless슬롯반환. 일부동시렌더기간은성능근거가아니다. 자동입력·렌더·자연플레이·사람수용을구별한다. 아트helper최종합본/fullCI/자연플레이/미감·재미·GPU/사운드/장시간은부모검증또는미검증으로남긴다.

진행:3단계 첫 권역 제작·히든출입/표기 / 이번까지코드·국소회귀 / 다음부모아트합본/fullCI / 사용자장소감·미감·자연플레이미검증.
