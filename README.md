# ORVO Flutter

첨부된 Flutter 기본 프로젝트를 기반으로 제공 이미지의 홈·주문·스플래시·기기·타이머·설정을 구현했습니다.

## 실행

Flutter 3.47.8 / Dart 3.13.7에서 검증합니다(백엔드 연결 뒤 Flutter 3.47.9에서도 `flutter analyze`·`flutter test` 통과, 11/6). Dart 3.13.5보다 낮으면 `flutter pub get`이 실패하니 `flutter upgrade`를 먼저 합니다.

```powershell
flutter pub get
flutter run
```

Android Studio에서 이 폴더를 Open하고, Settings → Languages & Frameworks → Flutter의 SDK 경로를 자기 PC의 Flutter 폴더로 지정하세요(`where flutter` 결과에서 `\bin\flutter`를 뺀 경로, 예: `C:\Users\jjh\Documents\Codex\tools\flutter`). Flutter/Dart 플러그인이 필요합니다.

실행 대상별 준비:

| 대상 | 명령 | 준비 |
| --- | --- | --- |
| 안드로이드 에뮬레이터(시연) | `flutter run` 또는 Android Studio ▶ | `flutter doctor --android-licenses`로 라이선스 승인 → Device Manager에서 Pixel 계열·x86_64 이미지로 에뮬레이터 만들기. 가속 오류가 나면 Windows 기능에서 **Windows 하이퍼바이저 플랫폼** 켜기 |
| Chrome | `flutter run -d chrome` | 없음 |
| Windows 앱 | `flutter run -d windows` | Visual Studio(VS Code 아님)의 "C++를 사용한 데스크톱 개발" |

## 화면과 동작

- 스플래시: ORVO 로고 → 1.8초 후 홈.
- 홈: 우측 상단 프로필 → 설정, 기기/주문/타이머 바로가기.
- 주문: 수락 → 조리 중 → 완료, 거절 확인 후 취소 처리. 버튼은 백엔드 API로 보냅니다.
- 기기: 2열 목록(1·2번 가스레인지, 전자레인지, 후드, 환풍기, 냉장고 온도). 전원, 가스레인지 화력, 기기별 타이머.
- 타이머: 접기/펼치기, 30초 조절(30초~5분), 시작/끄기. 끝나면 '시간이 다 됐어요'와 알람 끄기 버튼이 나옵니다.
- 설정: 서버 주소와 연결 상태, 알림·효과음·진동 UI, 음성 호출 활성화, 음성 UI 미리보기, 호출어 테스트 기록(안드로이드 실제 앱).
- 음성 패널: 앱 최상위에 있어 모든 탭과 설정 위에 표시됩니다. 호출 전에는 숨김 상태입니다.

## 백엔드 연결

화면은 백엔드(`Cookmate-HansungUnivTeamProject/Backend`)의 `GET /api/state`를 1초마다 읽어 그립니다. 버튼은 백엔드 API로 보내고, 응답이나 다음 상태로 화면을 다시 맞춥니다. 코드는 `lib/src/api.dart`(요청)와 `lib/src/store.dart`(상태)에 있습니다.

먼저 백엔드를 켭니다.

```powershell
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

서버 주소는 실행 대상마다 다릅니다. 기본값이 자동으로 들어가고, 앱 **설정 → 서버 → 바꾸기**에서 바꿀 수 있습니다(앱을 끄면 기본값으로 돌아감).

| 실행 대상 | 서버 주소 |
| --- | --- |
| Windows 앱, Chrome(같은 PC) | `http://127.0.0.1:8000` (기본값) |
| 안드로이드 에뮬레이터 | `http://10.0.2.2:8000` (기본값) |
| 실제 폰 | `http://<백엔드 PC의 IP>:8000`. 같은 와이파이, PC 방화벽에서 Python 허용 |

빌드할 때 기본값을 바꾸려면 `flutter run --dart-define=API_BASE=http://192.168.0.10:8000`.

연결 확인: 앱 **설정 → 서버**가 "연결됨"이면 붙은 것입니다. 그다음 PC 브라우저의 Swagger(`http://127.0.0.1:8000/docs`)에서 `POST /api/sim/order`(가짜 주문), `POST /api/sim/fridge {"temp": 8}`(냉장고 경고), `POST /api/commands`(음성 명령과 같은 경로)를 보내 앱 화면이 1초 안에 바뀌는지 봅니다.

지켜야 할 것(백엔드 규칙):
- POST에는 `Content-Type: application/json`을 붙입니다. 없으면 422입니다. `KitchenApi`가 붙여 줍니다.
- 기기 ID는 `gas_1`·`gas_2`·`hood`·`fan`·`microwave`, 타이머 ID는 `gas_1`·`gas_2`·`shared`·`microwave`입니다.
- 화력은 가스레인지만 1~3 정수입니다. 후드·환풍기는 세기가 없습니다.
- 타이머는 30초~5분, 30초 단위이고 일시정지가 없습니다. 끄면 초기화됩니다.
- 전자레인지는 타이머로 켭니다. 돌리면 켜지고, 끝나거나 끄면 꺼집니다. 전원 스위치로는 끄기만 됩니다.
- 가스레인지·공용 타이머는 기기 전원과 따로 동작합니다.
- 주문 버튼은 화면 번호(`slot`)가 아니라 주문 `id`로 부릅니다. 화면의 `주문 #N`은 음성으로 부르는 번호(`slot`)입니다.
- 안드로이드는 `AndroidManifest.xml`에 인터넷 권한과 `usesCleartextTraffic="true"`가 있어야 `http://`로 접속됩니다(넣어 둠).

아직 연결하지 않은 것: 라이더 호출 버튼, 알림(`alerts`) 소리·팝업. 음성 명령은 아래 '음성 호출어'(안드로이드 실제 폰)로 보냅니다.

## 음성 호출어 ("오르보", 안드로이드 실제 폰)

폰이 "오르보"를 듣고, 들은 명령 문장을 백엔드로 보냅니다. 소리를 글자로 바꾸는 것까지 폰 안에서 하고(인터넷 없음), 글자를 명령으로 바꾸는 AI는 백엔드가 부릅니다.

```
폰 마이크 → silero VAD(말소리 구간) → SenseVoice(한국어 글자) → "오르보" 판정 → POST /api/commands {text}
                                                              백엔드 → AI 서버(/predict) → 실행 → reply
```

- 코드: `lib/src/wake_word.dart`(판정, 순수 Dart), `lib/src/wake_engine.dart`(마이크·모델·흐름·테스트 기록 화면). 엔진은 안드로이드 실제 앱에서만 켜지고, 결과는 지금 있는 음성 패널(`VoiceController`)에 보입니다.
- 판정: 문장 맨 앞 2~4글자를 자모로 쪼개 "ㅇㅗㄹㅡㅂㅗ"와 비교해 1개까지 다르면 인정합니다("올보", "오로보", "어르보", "오르보야"는 받고 "오르면", "올려", "오븐"은 거절).
- "오르보, 후드 켜 줘"처럼 한 번에 말해도 되고, "오르보"만 말하면 6초 동안 다음 말을 명령으로 받습니다.
- 백엔드가 되묻으면(`needs_input`, "모든 기기를 켤까요?") 호출어 없이 다음 말을 받습니다. 확인 질문에는 "응·네·그래"면 다시 보내고 "아니·취소"면 취소합니다.
- 앱이 화면에 있을 때만 듣습니다(백그라운드에서는 마이크를 끔). 설정 → 음성 비서 → "오르보로 부르기"로 끄고 켭니다.

### 모델 받기 (처음 한 번)

`assets/models/`에 3개 파일을 넣습니다(약 240MB, git에 안 올림). PowerShell에서:

```powershell
cd assets\models
curl.exe -L -o silero_vad.onnx https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx
curl.exe -L -o sv.tar.bz2 https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2
tar -xjf sv.tar.bz2
move sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17\model.int8.onnx sense-voice.int8.onnx
move sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17\tokens.txt sense-voice-tokens.txt
Remove-Item -Recurse sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17, sv.tar.bz2
cd ..\..
```

### 시험하기 (폰 + PC)

1. PC에서 AI 서버(AI 저장소)를 켭니다: `uvicorn api:app --host 127.0.0.1 --port 8001`
2. PC에서 백엔드를 AI 주소와 함께 켭니다(백엔드 README 'AI 서버 연결').

   ```powershell
   $env:AI_SERVER_URL = "http://127.0.0.1:8001"
   uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```

3. 폰을 USB로 연결합니다(개발자 옵션 → USB 디버깅). 폰의 `127.0.0.1:8000`을 PC로 잇습니다. 와이파이가 기기끼리 막혀 있어도 됩니다.

   ```powershell
   adb reverse tcp:8000 tcp:8000
   flutter run --dart-define=API_BASE=http://127.0.0.1:8000
   ```

   `adb`가 없다고 나오면 `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`로 부릅니다. 처음 켤 때 마이크 권한을 허용하고, 모델 복사로 몇 초 기다립니다.
4. "오르보, 후드 켜 줘"라고 말하면 음성 패널에 들은 문장과 답이 뜨고, 후드 카드가 켜집니다.
5. 설정 → 음성 비서 → **호출어 테스트 기록**에서 들은 말마다 STT 글자, 호출어 판정(자모 거리), 보낸 명령, AI 명령, 답, 걸린 시간을 봅니다. 오른쪽 위 복사 버튼으로 표를 복사해 시트에 붙여 넣습니다.

에뮬레이터는 마이크 품질이 나빠 실제 폰으로 시험합니다. Chrome·Windows 앱에서는 엔진이 켜지지 않습니다.

## 온디바이스 연결 (다른 엔진을 붙일 때)

앱 안 엔진(`wake_engine.dart`) 대신 다른 wake-word/ASR 엔진을 쓰려면 아래 연결 지점을 씁니다. UI 미리보기는 마이크를 사용하지 않습니다.

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

- 기기·타이머·주문은 백엔드 서버 상태입니다. 서버에 연결되지 않으면 화면 위에 빨간 줄이 뜹니다.
- 타이머 숫자는 서버가 준 남은 시간으로 앱이 1초씩 줄이고, 1초마다 서버 상태로 맞춥니다. 앱 종료 후 알림, 백그라운드 서비스는 미구현입니다.
- 설정 토글은 세션 내 UI 상태이며 OS 알림/효과음/진동 기능은 연결되지 않았습니다.
- 제공 이미지에 프로필 원본이 없어 사람 아이콘을 사용했습니다.

## 검증

```powershell
flutter analyze
flutter test
```

`flutter test`는 실제 서버 없이 백엔드 규칙을 흉내 낸 가짜 서버(`test/widget_test.dart`의 `FakeBackend`)로 돕니다. 호출어 판정과 음성 명령 요청 모양은 `test/wake_word_test.dart`가 확인합니다(마이크·모델 없이).
