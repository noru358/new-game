# 하이브리드 장면의 동행 오디오 위치 수정

2.5D 장면은 Camera2D를 끄고 3D 카메라를 사용하지만, 기존 동행 발사/명중은 AudioStreamPlayer2D였다. 명시적 AudioListener2D가 없어 넓은 맵에서 청취점이 플레이어와 함께 이동하지 않았다.

Godot4.6 공식 구현은 명시적 listener가 없을 때 2D canvas 기준 화면 중심을 쓰고, 음원과의 거리가 max_distance를 넘으면 출력하지 않는다. 근거: https://github.com/godotengine/godot/blob/4.6-stable/scene/2d/audio_stream_player_2d.cpp (listener/panning calculation), https://docs.godotengine.org/en/4.5/classes/class_audiolistener2d.html .

수정은 HybridHeight의 실제 플레이어 아래 listener 하나를 두고 현재 사선 시점에 맞춰 -45도 회전하는 것이다. 기존 파일/볼륨/거리 감쇠/음소거 정책은 유지한다. 일반 2D 원형 프로토타입의 Camera2D는 바꾸지 않는다.

로컬 Godot4.6.3 AudioEffectCapture + Dummy mixer에서 실제 wisp_shot.wav를 재생했다. (5030,1470) 음원 / (5000,1500) 플레이어 표본의 수정 전 출력RMS(0,0), 수정 후(0.008119,0.008393). 같은 상대거리로 플레이어를(1000,1500)에 옮겨도 같은RMS. 사선 화면 우/좌에서 채널 비중도 맞았다. 총7검사 통과. 이전 재생을 비우지 않고 곧바로 재시작한 첫 측정은 mixer 잔여분과 분리되지 않아 비교에 쓰지 않는다.

이는 엔진 믹서 출력/좌표 계약 확인이지 사람의 청취·음색 선호·사용자Mac 음량 확인이 아니다. root/headless guard를 우회해 게임전체음을 강제로 켠 것이 아니라 테스트가 기존 음원 노드를 직접 재생했다. 일반 저장/경제/전투/가림/타이머는 변경하지 않는다. 정확한 원격4.6 전체검사는 이 브랜치에서 이어서 확인한다.
