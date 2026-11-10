import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An adapter for a future native wake-word and on-device ASR engine.
/// This class does not start microphone capture or use a cloud service.
class VoiceController extends ChangeNotifier {
  static const events = EventChannel('orvo/voice_events');
  static const commands = MethodChannel('orvo/voice_control');
  StreamSubscription<dynamic>? _subscription;
  Timer? _dismiss;
  bool enabled = true;

  /// 오르보의 답을 소리로 읽을지(설정 → 음성 비서 → "답을 소리로 읽기").
  bool speakReplies = true;
  bool visible = false;
  bool connected = false;
  String phase = 'listening';
  String transcript = '';
  String response = '';
  void connect() {
    if (kIsWeb || _subscription != null) return;
    _subscription = events.receiveBroadcastStream().listen(
      receive,
      onError: (_) {
        connected = false;
        notifyListeners();
      },
    );
  }

  void receive(dynamic raw) {
    if (raw is! Map || !enabled) return;
    final type = raw['type'];
    if (type == 'ready') {
      connected = true;
      notifyListeners();
      return;
    }
    if (type == 'dismiss') {
      hide();
      return;
    }
    if (!['wake', 'partial', 'final', 'response', 'error'].contains(type)) {
      return;
    }
    _dismiss?.cancel();
    visible = true;
    if (type == 'wake') {
      transcript = '';
      response = '';
      phase = 'listening';
    } else if (type == 'partial' || type == 'final') {
      transcript = raw['text']?.toString() ?? '';
      phase = type == 'final' ? 'processing' : 'listening';
    } else {
      response = raw['text']?.toString() ?? '';
      phase = type == 'error' ? 'error' : 'response';
    }
    _dismiss = Timer(Duration(seconds: phase == 'listening' ? 15 : 8), hide);
    notifyListeners();
  }

  /// 앱 안의 호출어 엔진(wake_engine.dart)이 듣기 시작하거나 멈출 때 부른다.
  void setEngineConnected(bool value) {
    if (connected == value) return;
    connected = value;
    notifyListeners();
  }

  void setSpeakReplies(bool value) {
    if (speakReplies == value) return;
    speakReplies = value;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    if (!value) hide();
    try {
      await commands.invokeMethod<void>('setEnabled', {'enabled': value});
    } on MissingPluginException {
      connected = false;
    } on PlatformException {
      connected = false;
    }
    notifyListeners();
  }

  void preview() {
    receive({'type': 'wake'});
    receive({'type': 'partial', 'text': '오르보, 주방 상태 알려줘'});
  }

  void hide() {
    _dismiss?.cancel();
    visible = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
