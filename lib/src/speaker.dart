// 오르보의 답을 소리로 읽는다(TTS).
//
// 지금은 폰에 이미 있는 TTS 엔진(갤럭시는 삼성 TTS, 그 밖에는 구글 TTS)을 flutter_tts로 쓴다.
// 나중에 앱 안 모델(sherpa-onnx 등)로 바꿀 때는 [TtsBackend]만 새로 만들면 된다.

import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// 실제로 소리를 내는 부분. 테스트에서는 가짜로 바꾼다.
abstract class TtsBackend {
  /// [language](예: ko-KR)로 읽을 준비를 한다. 그 언어 음성이 없으면 false.
  Future<bool> prepare(String language);

  /// [text]를 읽고, 다 읽거나 멈추거나 실패하면 끝난다.
  Future<void> speak(String text);

  /// 읽던 것을 멈춘다.
  Future<void> stop();
}

/// 폰의 TTS 엔진(안드로이드 TextToSpeech)을 쓰는 [TtsBackend].
class FlutterTtsBackend implements TtsBackend {
  FlutterTtsBackend() {
    // 다 읽음·멈춤·오류 모두 "끝"으로 본다. 오류일 때 speak()가 끝나지 않고 기다리는 일이 없게
    // awaitSpeakCompletion 대신 이 알림으로 끝을 잡는다.
    _tts.setCompletionHandler(_finish);
    _tts.setCancelHandler(_finish);
    _tts.setErrorHandler((_) => _finish());
  }

  final _tts = FlutterTts();
  Completer<void>? _done;

  void _finish() {
    final done = _done;
    _done = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  @override
  Future<bool> prepare(String language) async {
    if (await _tts.isLanguageAvailable(language) != true) return false;
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(0.5); // 안드로이드 기본 속도
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(false);
    return true;
  }

  @override
  Future<void> speak(String text) async {
    _finish(); // 앞에 읽던 것이 남아 있으면 끝난 것으로 친다
    final done = _done = Completer<void>();
    // focus: 읽는 동안 음악 등 다른 소리를 잠깐 멈춘다.
    final started = await _tts.speak(text, focus: true);
    if (started != 1) _finish();
    await done.future;
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } finally {
      _finish();
    }
  }
}

/// 읽기 전에 글자를 다듬는다. 괄호 안(서버 주소 등)과 URL은 읽지 않는다.
/// 예: "서버에 연결할 수 없어요 (http://127.0.0.1:8000)" → "서버에 연결할 수 없어요"
String spokenText(String text) => text
    .replaceAll(RegExp(r'\([^)]*\)'), ' ')
    .replaceAll(RegExp(r'https?://\S+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// 읽는 데 걸릴 최대 시간. 이보다 길면 멈춘다(엔진이 끝을 알려 주지 않아도 멈춰 있지 않게).
/// 한국어 TTS는 1초에 6~7글자쯤 읽는다. 넉넉하게 글자당 0.25초 + 시작 3초, 최대 30초.
Duration defaultSpeakLimit(String text) {
  final ms = 3000 + 250 * text.length;
  return Duration(milliseconds: ms > 30000 ? 30000 : ms);
}

/// 오르보의 답을 읽어 주는 곳. [say]는 다 읽은 뒤에 끝나서, 그동안 마이크를 막아 둘 수 있다.
class Speaker {
  Speaker({
    TtsBackend? backend,
    this.language = 'ko-KR',
    this.limit = defaultSpeakLimit,
  }) : _backend = backend ?? FlutterTtsBackend();

  final TtsBackend _backend;

  /// 읽을 언어.
  final String language;

  /// 글자별 최대 읽기 시간.
  final Duration Function(String text) limit;

  /// 마지막 문제(한국어 음성 없음 등). 없으면 빈 문자열.
  String problem = '';

  bool _speaking = false;
  Future<bool>? _ready;

  /// 지금 읽고 있는지.
  bool get speaking => _speaking;

  Future<bool> _prepare() {
    return _ready ??= () async {
      try {
        final ok = await _backend
            .prepare(language)
            .timeout(const Duration(seconds: 5), onTimeout: () => false);
        problem = ok ? '' : '폰에 한국어 TTS 음성이 없어요. 폰 설정의 TTS(텍스트 음성 변환)에서 한국어 음성을 받아 주세요.';
        if (!ok) _ready = null; // 음성을 받은 뒤 다시 시도할 수 있게
        return ok;
      } catch (e) {
        problem = 'TTS를 켜지 못했어요: $e';
        _ready = null;
        return false;
      }
    }();
  }

  /// [text]를 읽는다. 다 읽거나 멈추면 끝난다. 읽을 수 없으면 조용히 넘어간다([problem]에 이유).
  Future<void> say(String text) async {
    final words = spokenText(text);
    if (words.isEmpty) return;
    if (!await _prepare()) return;
    _speaking = true;
    try {
      await _backend.speak(words).timeout(limit(words), onTimeout: _backend.stop);
    } catch (e) {
      problem = '읽지 못했어요: $e';
    } finally {
      _speaking = false;
    }
  }

  /// 읽던 것을 멈춘다.
  Future<void> stop() async {
    if (!_speaking) return;
    try {
      await _backend.stop();
    } catch (_) {
      // 이미 멈춤
    }
  }
}
