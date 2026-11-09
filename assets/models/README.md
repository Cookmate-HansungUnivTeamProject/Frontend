# 음성 모델 (git에 안 올림)

"오르보" 호출어 엔진(`lib/src/wake_engine.dart`)이 쓰는 모델입니다. 이 폴더에 아래 3개 파일을 넣고 빌드하세요.

| 파일 | 크기 | 어디서 |
| --- | --- | --- |
| `silero_vad.onnx` | 0.6MB | sherpa-onnx `asr-models` 릴리스의 `silero_vad.onnx` |
| `sense-voice.int8.onnx` | 239MB | `sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2` 안의 `model.int8.onnx` |
| `sense-voice-tokens.txt` | 0.3MB | 같은 압축 파일 안의 `tokens.txt` |

받는 명령은 프로젝트 README의 '음성 호출어 → 모델 받기'에 있습니다.
