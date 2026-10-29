# ORVO Flutter

첨부된 Flutter 기본 프로젝트를 기반으로 제공 이미지의 홈·주문·스플래시·기기·타이머·설정을 구현했습니다.

## 실행

Flutter 3.47.8 / Dart 3.13.7에서 검증합니다.

```powershell
flutter pub get
flutter run
```

Android Studio에서 이 폴더를 Open하고 Flutter SDK 경로를 `C:\Users\jjh\Documents\Codex\tools\flutter`로 지정하세요. Flutter/Dart 플러그인이 필요합니다.

## 화면과 동작

- 스플래시: ORVO 로고 → 1.8초 후 홈.
- 홈: 우측 상단 프로필 → 설정, 기기/주문/타이머 바로가기.
- 주문: 수락 → 조리 중 → 완료, 거절 확인 후 취소 처리.
- 기기: 2열 목록, 전원과 강도 조절, 기기별 타이머.
- 타이머: 접기/펼치기, 30초 조절, 시작/일시정지/초기화. 종료 시 남은 시간이 0으로 표시됩니다.
- 설정: 알림·효과음·진동 UI, 음성 호출 활성화, 음성 UI 미리보기.
- 음성 패널: 앱 최상위에 있어 모든 탭과 설정 위에 표시됩니다. 호출 전에는 숨김 상태입니다.

## 온디바이스 연결

실제 wake-word/ASR 모델은 포함되어 있지 않습니다. UI 미리보기는 마이크를 사용하지 않습니다. 엔진을 연결하기 전에는 실제 말로 호출할 수 없습니다.

Android의 `MainActivity.kt`에 `OrvoVoiceBridge` 연결 지점이 있습니다. 온디바이스 엔진에서 다음 이벤트를 보내세요. 작업 스레드에서 호출해도 메인 스레드로 전달됩니다.

```kotlin
OrvoVoiceBridge.onEnabledChanged = { enabled ->
    // 실제 엔진의 시작/중지 또는 wake-word 감지 활성화를 처리
}
OrvoVoiceBridge.engineReady()
// 엔진이 "오르보" 호출을 감지한 뒤:
OrvoVoiceBridge.emit("wake")
OrvoVoiceBridge.emit("partial", "오르보, 타이머 3분 설정해줘")
OrvoVoiceBridge.emit("final", "타이머 3분 설정해줘")
// 명령 라우터가 실제 기기 응답을 확인한 뒤:
OrvoVoiceBridge.emit("response", "타이머를 설정했어요")
// 오류 또는 닫기:
OrvoVoiceBridge.emit("error", "다시 말씀해 주세요")
OrvoVoiceBridge.emit("dismiss")
```

채널: `orvo/voice_events` (EventChannel), `orvo/voice_control` (MethodChannel, `setEnabled` + `{enabled: bool}`).

`wake` 이벤트는 반드시 실제 호출어 검출 뒤에 전송하세요. Flutter는 wake-word를 직접 인식하지 않습니다. 마이크 권한·오디오 수집·모델 로딩·백그라운드 서비스는 엔진 구현에서 처리해야 합니다. 기기 명령은 텍스트만으로 자동 실행하지 않으며, 실제 연결 계층에서 처리하고 성공 여부를 확인한 뒤 응답 이벤트를 보내세요. iOS는 동일 채널을 별도로 구현해야 합니다.

## 현재 범위

- 기기와 주문은 메모리 내 데모 데이터입니다. 서버/IoT 연결 및 저장은 포함되지 않습니다.
- 타이머는 deadline 기준으로 계산하여 탭 이동 후에도 일관됩니다. 앱 종료 후 알림, 백그라운드 서비스는 미구현입니다.
- 설정 토글은 세션 내 UI 상태이며 OS 알림/효과음/진동 기능은 연결되지 않았습니다.
- 제공 이미지에 프로필 원본이 없어 사람 아이콘을 사용했습니다.

## 검증

```powershell
flutter analyze
flutter test
```
