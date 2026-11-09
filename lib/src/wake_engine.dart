// 폰 마이크로 "오르보"를 듣고, 들은 명령 문장을 백엔드로 보내는 엔진. 안드로이드 실제 앱에서만 켠다.
//
// 마이크(16kHz) → [작업 isolate: silero VAD로 말 구간 자르기 → SenseVoice(한국어)로 글자]
//   → "오르보" 판정(wake_word.dart) → POST /api/commands {text}
//   → 백엔드가 AI 서버로 명령을 받아 실행하고 답(reply)을 돌려준다(백엔드에 AI_SERVER_URL 필요).
//
// 모델 파일은 assets/models/에 넣는다(README '음성 호출어'). 인터넷 없이 폰 안에서만 처리한다.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'api.dart';
import 'store.dart';
import 'voice.dart';
import 'wake_word.dart';

/// 앱에 넣는 모델 파일(pubspec.yaml의 assets/models/).
const vadModelAsset = 'assets/models/silero_vad.onnx';
const asrModelAsset = 'assets/models/sense-voice.int8.onnx';
const asrTokensAsset = 'assets/models/sense-voice-tokens.txt';

const _sampleRate = 16000;
const _idleMessage = '"오르보"를 기다리는 중';

/// 엔진 상태.
enum WakeStatus {
  /// 꺼짐(설정에서 끔, 또는 앱이 뒤로 감).
  off,

  /// 모델 준비 중(처음 한 번은 모델을 폰 저장소로 복사해서 몇 초 걸림).
  loading,

  /// "오르보"를 기다리는 중.
  idle,

  /// 호출어를 들었고 명령을 기다리는 중(또는 백엔드가 되물은 뒤 대답을 기다리는 중).
  listening,

  /// 명령을 백엔드로 보내고 답을 기다리는 중.
  busy,

  /// 마이크 권한 없음, 모델 파일 없음 등.
  error,
}

/// 테스트 기록 한 줄. STT가 글자를 낼 때마다 하나씩 쌓인다.
class WakeLogEntry {
  WakeLogEntry({
    required this.time,
    required this.heard,
    required this.sttMs,
    required this.audioMs,
    this.match,
  });

  final DateTime time;

  /// STT가 적은 글자 그대로.
  final String heard;

  /// STT에 걸린 시간(ms).
  final int sttMs;

  /// 말소리 길이(ms).
  final int audioMs;

  /// 호출어 판정 결과. 명령을 기다리던 중에 들은 말이면 null.
  final WakeMatch? match;

  /// 처리 결과 설명(호출어 · 호출어 아님 · 명령 · 처리 중이라 무시 …).
  String note = '';

  /// 백엔드로 보낸 명령 글자.
  String command = '';

  /// 백엔드 답.
  String reply = '';

  /// 백엔드 ok 값. 보내지 않았으면 null.
  bool? ok;

  /// AI가 만든 명령(백엔드 응답의 raw).
  String raw = '';

  /// 말이 끝난 뒤 답을 받을 때까지(STT + 백엔드·AI, ms). 보내지 않았으면 0.
  int totalMs = 0;
}

class _PendingConfirm {
  const _PendingConfirm(this.text, this.raw, this.requestId);
  final String text;
  final String raw;
  final String requestId;
}

/// "오르보" 호출어 엔진. [VoiceController]에 이벤트를 넣어 지금 있는 음성 패널을 그대로 쓴다.
class WakeEngine extends ChangeNotifier {
  WakeEngine({
    required this.voice,
    required this.store,
    this.listenWindow = const Duration(seconds: 6),
  }) {
    voice.addListener(_onVoiceChanged);
    _lifecycle = AppLifecycleListener(onPause: _pauseMic, onResume: _resumeMic);
    _onVoiceChanged(); // 설정의 "오르보로 부르기"가 켜져 있으면 바로 듣기 시작
  }

  /// 실제 마이크·모델을 쓸 수 있는 곳(안드로이드 앱)인지.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final VoiceController voice;
  final KitchenStore store;

  /// "오르보"만 말했거나 백엔드가 되물은 뒤, 다음 말을 기다리는 시간.
  final Duration listenWindow;

  WakeStatus status = WakeStatus.off;

  /// 상태 설명(오류 이유 등).
  String message = '';

  /// VAD가 지금 사람 말소리를 듣고 있는지.
  bool speaking = false;

  /// 최근 기록(새것이 앞). 200개까지.
  final List<WakeLogEntry> log = [];

  late final AppLifecycleListener _lifecycle;
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _micSub;
  Isolate? _worker;
  ReceivePort? _fromWorker;
  SendPort? _toWorker;
  Timer? _windowTimer;
  _PendingConfirm? _pendingConfirm;
  bool _wanted = false; // 사용자가 켜 두었는지(설정 스위치)
  bool _starting = false;
  bool _disposed = false;
  int _requestSeq = 0;

  bool get running => _micSub != null;

  void _onVoiceChanged() {
    if (voice.enabled == _wanted) return;
    if (voice.enabled) {
      unawaited(start());
    } else {
      unawaited(stop());
    }
  }

  /// 마이크와 모델을 켠다. 이미 켜져 있으면 아무것도 하지 않는다.
  Future<void> start() async {
    _wanted = true;
    if (_starting || running || _disposed) return;
    _starting = true;
    try {
      if (_toWorker == null) {
        _set(WakeStatus.loading, '음성 모델 준비 중(처음 한 번은 몇 초 걸려요)');
        final paths = await _prepareModels();
        await _startWorker(paths);
      }
      if (!_wanted || _disposed) return;
      await _startMic();
    } on _WakeSetupError catch (e) {
      _set(WakeStatus.error, e.message);
    } catch (e) {
      _set(WakeStatus.error, '음성 엔진을 켜지 못했어요: $e');
    } finally {
      _starting = false;
    }
  }

  /// 마이크를 끈다(모델은 메모리에 남겨 다시 켤 때 빠르게).
  Future<void> stop() async {
    _wanted = false;
    await _stopMic();
    _endWindow();
    voice.setEngineConnected(false);
    _set(WakeStatus.off, '');
  }

  Future<void> _pauseMic() async {
    if (running) {
      await _stopMic();
      _endWindow();
      _set(WakeStatus.off, '앱이 화면에 없을 때는 듣지 않아요');
    }
  }

  Future<void> _resumeMic() async {
    if (_wanted && !running) {
      await start();
    }
  }

  // ---------------------------------------------------------------- 준비

  /// 모델을 앱 저장소로 복사한다(sherpa-onnx는 파일 경로로 읽음). 다 복사한 파일은 다시 복사하지 않는다.
  Future<Map<String, String>> _prepareModels() async {
    final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'models'));
    await dir.create(recursive: true);
    final out = <String, String>{};
    for (final asset in [vadModelAsset, asrModelAsset, asrTokensAsset]) {
      final target = File(p.join(dir.path, p.basename(asset)));
      final done = File('${target.path}.done');
      if (await target.exists() && await done.exists() &&
          (await done.readAsString()).trim() == '${await target.length()}') {
        out[asset] = target.path;
        continue;
      }
      final ByteData data;
      try {
        data = await rootBundle.load(asset);
      } catch (_) {
        throw _WakeSetupError('모델 파일이 없어요: $asset\nREADME의 "음성 호출어 → 모델 받기"를 먼저 하세요.');
      }
      final temp = File('${target.path}.part');
      await temp.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      await temp.rename(target.path);
      await done.writeAsString('${data.lengthInBytes}', flush: true);
      out[asset] = target.path;
    }
    return out;
  }

  Future<void> _startWorker(Map<String, String> paths) async {
    final port = ReceivePort();
    final ready = Completer<SendPort>();
    port.listen((message) {
      if (message is SendPort) {
        ready.complete(message);
      } else if (message is Map) {
        _onWorkerMessage(message);
      } else if (message is List) {
        // isolate가 죽음(onError: [오류, 스택])
        final error = message.isEmpty ? '알 수 없는 오류' : '${message.first}';
        if (!ready.isCompleted) {
          ready.completeError(_WakeSetupError('음성 모델을 불러오지 못했어요: $error'));
        } else {
          _toWorker = null;
          unawaited(_stopMic());
          _set(WakeStatus.error, '음성 인식이 멈췄어요: $error');
        }
      }
    });
    _fromWorker = port;
    try {
      _worker = await Isolate.spawn(
        _workerMain,
        _WorkerInit(
          port.sendPort,
          paths[vadModelAsset]!,
          paths[asrModelAsset]!,
          paths[asrTokensAsset]!,
        ),
        onError: port.sendPort,
        errorsAreFatal: true,
      );
      _toWorker = await ready.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw _WakeSetupError('음성 모델을 불러오지 못했어요(시간 초과)'),
      );
    } catch (_) {
      // 다음 start()에서 처음부터 다시 띄우게 정리한다.
      port.close();
      _worker?.kill(priority: Isolate.immediate);
      _worker = null;
      _fromWorker = null;
      _toWorker = null;
      rethrow;
    }
  }

  Future<void> _startMic() async {
    final recorder = _recorder ??= AudioRecorder();
    if (!await recorder.hasPermission()) {
      throw _WakeSetupError('마이크 권한이 필요해요. 폰 설정 → 앱 → frontend → 권한에서 마이크를 허용하세요.');
    }
    final stream = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ),
    );
    _toWorker?.send('reset');
    _micSub = stream.listen(
      (chunk) => _toWorker?.send(chunk),
      onError: (Object e) => _set(WakeStatus.error, '마이크 오류: $e'),
    );
    voice.setEngineConnected(true);
    _idle();
  }

  Future<void> _stopMic() async {
    final sub = _micSub;
    _micSub = null;
    await sub?.cancel();
    try {
      await _recorder?.stop();
    } catch (_) {
      // 이미 멈춘 경우
    }
    speaking = false;
  }

  // ---------------------------------------------------------------- 들은 말 처리

  void _onWorkerMessage(Map<dynamic, dynamic> message) {
    if (_disposed) return;
    if (message.containsKey('speech')) {
      speaking = message['speech'] == true;
      notifyListeners();
      return;
    }
    if (message.containsKey('error')) {
      _set(WakeStatus.error, '음성 인식 오류: ${message['error']}');
      return;
    }
    final text = (message['text'] as String? ?? '').trim();
    if (text.isEmpty || !running) return;
    _onHeard(
      text,
      message['sttMs'] as int? ?? 0,
      message['audioMs'] as int? ?? 0,
    );
  }

  void _onHeard(String text, int sttMs, int audioMs) {
    _handleHeard(text, sttMs, audioMs);
    if (!_disposed) notifyListeners(); // 기록 화면 갱신(판정 메모까지 채운 뒤)
  }

  void _handleHeard(String text, int sttMs, int audioMs) {
    if (status == WakeStatus.busy) {
      _addLog(WakeLogEntry(time: DateTime.now(), heard: text, sttMs: sttMs, audioMs: audioMs)
        ..note = '처리 중이라 무시');
      return;
    }

    if (status == WakeStatus.listening) {
      final again = matchWake(text);
      final entry = WakeLogEntry(
        time: DateTime.now(),
        heard: text,
        sttMs: sttMs,
        audioMs: audioMs,
        match: again.matched ? again : null,
      );
      _addLog(entry);
      // 명령을 기다리는 중에도 "오르보 …"라고 다시 부르면 호출어는 떼고 쓴다.
      final command = again.matched ? again.command : stripSentenceEnd(text);
      if (command.isEmpty) {
        entry.note = '호출어(다시)';
        _startWindow();
        voice.receive({'type': 'wake'});
        return;
      }
      final confirm = _pendingConfirm;
      if (confirm != null) {
        _pendingConfirm = null;
        final answer = yesOrNo(command);
        if (answer == true) {
          entry.note = '확인: 예';
          unawaited(_send(entry, confirm.text, sttMs,
              raw: confirm.raw, confirm: true, requestId: confirm.requestId));
          return;
        }
        if (answer == false) {
          entry.note = '확인: 아니요';
          _endWindow();
          voice.receive({'type': 'response', 'text': '취소했어요.'});
          _idle();
          return;
        }
      }
      entry.note = '명령';
      unawaited(_send(entry, command, sttMs));
      return;
    }

    final match = matchWake(text);
    final entry = WakeLogEntry(
      time: DateTime.now(),
      heard: text,
      sttMs: sttMs,
      audioMs: audioMs,
      match: match,
    );
    _addLog(entry);
    if (!match.matched) {
      entry.note = '호출어 아님';
      return;
    }
    if (match.command.isEmpty) {
      entry.note = '호출어';
      voice.receive({'type': 'wake'});
      _startWindow();
      return;
    }
    entry.note = '호출어 + 명령';
    voice.receive({'type': 'wake'});
    unawaited(_send(entry, match.command, sttMs));
  }

  Future<void> _send(
    WakeLogEntry entry,
    String command,
    int sttMs, {
    String raw = '',
    bool confirm = false,
    String? requestId,
  }) async {
    _endWindow();
    _set(WakeStatus.busy, '명령 처리 중');
    entry.command = command;
    voice.receive({'type': 'final', 'text': command});
    final id = requestId ?? 'v${DateTime.now().microsecondsSinceEpoch}-${_requestSeq++}';
    final watch = Stopwatch()..start();
    try {
      final res = await store.api.command(command, raw: raw, confirm: confirm, requestId: id);
      if (_disposed) return;
      final reply = res['reply'] as String? ?? '';
      entry
        ..ok = res['ok'] == true
        ..reply = reply
        ..raw = res['raw'] as String? ?? '';
      voice.receive({
        'type': entry.ok! ? 'response' : 'error',
        'text': reply.isEmpty ? '(답 없음)' : reply,
      });
      if (res['needs_confirm'] == true) {
        _pendingConfirm = _PendingConfirm(command, entry.raw, id);
        _startWindow();
      } else if (res['needs_input'] == true) {
        _startWindow();
      } else {
        _idle();
      }
      unawaited(store.refresh()); // 기기 카드를 1초 기다리지 않고 바로 맞춘다
    } on ApiException catch (e) {
      if (_disposed) return;
      entry
        ..ok = false
        ..reply = e.message;
      voice.receive({'type': 'error', 'text': e.message});
      _idle();
    } catch (e) {
      // 예상 못 한 응답 모양 등. '처리 중'에 멈춰 다음 말을 못 듣는 일이 없게 한다.
      if (_disposed) return;
      entry
        ..ok = false
        ..reply = '앱 오류: $e';
      voice.receive({'type': 'error', 'text': '다시 말씀해 주세요'});
      _idle();
    } finally {
      entry.totalMs = sttMs + watch.elapsedMilliseconds;
      if (!_disposed) notifyListeners();
    }
  }

  /// 마이크가 켜져 있을 때만 "오르보" 대기로 돌아간다(그사이 앱이 뒤로 갔으면 꺼짐 상태 그대로).
  void _idle() {
    if (running) _set(WakeStatus.idle, _idleMessage);
  }

  void _startWindow() {
    _windowTimer?.cancel();
    if (!running) return;
    _set(WakeStatus.listening, '명령을 기다리는 중');
    _windowTimer = Timer(listenWindow, () {
      _pendingConfirm = null;
      if (status == WakeStatus.listening) {
        voice.hide();
        _idle();
      }
    });
  }

  void _endWindow() {
    _windowTimer?.cancel();
    _windowTimer = null;
  }

  void _addLog(WakeLogEntry entry) {
    log.insert(0, entry);
    if (log.length > 200) log.removeLast();
  }

  void clearLog() {
    log.clear();
    notifyListeners();
  }

  /// 기록을 탭으로 구분한 표로(엑셀·구글 시트에 붙여 넣기 좋게).
  String logAsTable() {
    final rows = <String>[
      '시각\t들은 말\t판정\t자모 거리\t보낸 명령\tAI 명령\t답\tok\tSTT ms\t말 길이 ms\t전체 ms',
    ];
    for (final e in log.reversed) {
      rows.add([
        e.time.toIso8601String(),
        e.heard,
        e.note,
        e.match?.distance.toString() ?? '',
        e.command,
        e.raw,
        e.reply,
        e.ok?.toString() ?? '',
        '${e.sttMs}',
        '${e.audioMs}',
        '${e.totalMs}',
      ].map((v) => v.replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t'));
    }
    return rows.join('\n');
  }

  void _set(WakeStatus value, String text) {
    if (_disposed) return;
    status = value;
    message = text;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    voice.removeListener(_onVoiceChanged);
    _lifecycle.dispose();
    _windowTimer?.cancel();
    _micSub?.cancel();
    _recorder?.dispose();
    _toWorker?.send('close');
    _fromWorker?.close();
    _worker?.kill(priority: Isolate.beforeNextEvent);
    super.dispose();
  }
}

class _WakeSetupError implements Exception {
  _WakeSetupError(this.message);
  final String message;
}

// ---------------------------------------------------------------- 작업 isolate (VAD + STT)

class _WorkerInit {
  const _WorkerInit(this.reply, this.vadModel, this.asrModel, this.tokens);
  final SendPort reply;
  final String vadModel;
  final String asrModel;
  final String tokens;
}

/// 마이크 PCM16 조각을 받아 말 구간마다 글자를 돌려준다. 화면이 버벅이지 않게 따로 돈다.
Future<void> _workerMain(_WorkerInit init) async {
  await sherpa_onnx.initBindingsAsync();
  final vad = sherpa_onnx.VoiceActivityDetector(
    config: sherpa_onnx.VadModelConfig(
      sileroVad: sherpa_onnx.SileroVadModelConfig(
        model: init.vadModel,
        threshold: 0.5,
        minSilenceDuration: 0.6, // 0.6초 쉬면 말이 끝난 것으로 봄("오르보, … 켜 줘" 사이 짧은 쉼은 이어 붙임)
        minSpeechDuration: 0.25, // 그릇 소리 같은 짧은 소리는 말로 치지 않음
        maxSpeechDuration: 8.0,
      ),
      sampleRate: _sampleRate,
      numThreads: 1,
      debug: false,
    ),
    bufferSizeInSeconds: 30,
  );
  final recognizer = sherpa_onnx.OfflineRecognizer(
    sherpa_onnx.OfflineRecognizerConfig(
      model: sherpa_onnx.OfflineModelConfig(
        senseVoice: sherpa_onnx.OfflineSenseVoiceModelConfig(
          model: init.asrModel,
          language: 'ko',
          useInverseTextNormalization: true, // "일 번" → "1번"(수업 음성 설정과 같게)
        ),
        tokens: init.tokens,
        numThreads: 2,
        debug: false,
      ),
    ),
  );

  final port = ReceivePort();
  init.reply.send(port.sendPort);

  const window = 512; // silero VAD가 한 번에 받는 샘플 수(32ms)
  final pending = <double>[];
  int? carry; // PCM16 조각이 홀수 바이트로 끊겼을 때 남은 1바이트
  var speaking = false;

  await for (final message in port) {
    if (message is Uint8List) {
      var bytes = message;
      if (carry != null) {
        bytes = Uint8List.fromList([carry, ...message]);
        carry = null;
      }
      final usable = bytes.length - bytes.length % 2;
      if (usable < bytes.length) carry = bytes[bytes.length - 1];
      final data = ByteData.sublistView(bytes, 0, usable);
      for (var i = 0; i < usable; i += 2) {
        pending.add(data.getInt16(i, Endian.little) / 32768.0);
      }
      while (pending.length >= window) {
        vad.acceptWaveform(Float32List.fromList(pending.sublist(0, window)));
        pending.removeRange(0, window);
        final now = vad.isDetected();
        if (now != speaking) {
          speaking = now;
          init.reply.send({'speech': now});
        }
        while (!vad.isEmpty()) {
          final samples = vad.front().samples;
          vad.pop();
          final watch = Stopwatch()..start();
          try {
            final stream = recognizer.createStream();
            stream.acceptWaveform(samples: samples, sampleRate: _sampleRate);
            recognizer.decode(stream);
            final text = recognizer.getResult(stream).text;
            stream.free();
            init.reply.send({
              'text': text,
              'sttMs': watch.elapsedMilliseconds,
              'audioMs': samples.length * 1000 ~/ _sampleRate,
            });
          } catch (e) {
            init.reply.send({'error': '$e'});
          }
        }
      }
    } else if (message == 'reset') {
      vad.reset();
      pending.clear();
      carry = null;
      speaking = false;
    } else if (message == 'close') {
      vad.free();
      recognizer.free();
      port.close();
    }
  }
}

// ---------------------------------------------------------------- 테스트 기록 화면

/// 설정 → 음성 비서 → "호출어 테스트 기록". 들은 말마다 판정·명령·답·시간을 보여 준다.
class WakeLogPage extends StatelessWidget {
  const WakeLogPage({super.key, required this.engine});
  final WakeEngine engine;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('호출어 테스트 기록'),
      actions: [
        IconButton(
          tooltip: '표로 복사',
          icon: const Icon(Icons.copy),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: engine.logAsTable()));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('기록을 복사했어요. 엑셀·시트에 붙여 넣으세요.')),
            );
          },
        ),
        IconButton(
          tooltip: '지우기',
          icon: const Icon(Icons.delete_outline),
          onPressed: engine.clearLog,
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final heard = engine.log.where((e) => e.match != null).toList();
        final woke = heard.where((e) => e.match!.matched).length;
        final sent = engine.log.where((e) => e.ok != null).toList();
        final sttAvg = engine.log.isEmpty
            ? 0
            : engine.log.map((e) => e.sttMs).reduce((a, b) => a + b) ~/ engine.log.length;
        final totalAvg = sent.isEmpty
            ? 0
            : sent.map((e) => e.totalMs).reduce((a, b) => a + b) ~/ sent.length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${engine.speaking ? '🎙 말소리 듣는 중' : '조용함'} · ${engine.message}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              '호출어 판정 ${heard.length}번 중 인정 $woke번 · '
              '명령 ${sent.length}번(성공 ${sent.where((e) => e.ok == true).length}) · '
              'STT 평균 ${sttAvg}ms · 명령 전체 평균 ${totalAvg}ms',
              style: const TextStyle(fontSize: 13),
            ),
            const Divider(height: 24),
            if (engine.log.isEmpty)
              const Text('"오르보, 후드 켜 줘"처럼 말해 보세요. 들은 말이 여기에 쌓여요.'),
            for (final e in engine.log) _LogTile(entry: e),
          ],
        );
      },
    ),
  );
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});
  final WakeLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final time = '${e.time.hour.toString().padLeft(2, '0')}:'
        '${e.time.minute.toString().padLeft(2, '0')}:'
        '${e.time.second.toString().padLeft(2, '0')}';
    final judged = e.match == null
        ? ''
        : ' · 앞부분 "${e.match!.heard}" 거리 ${e.match!.distance}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$time  ${e.note}$judged', style: const TextStyle(fontSize: 12, color: Colors.white60)),
          Text('들음: ${e.heard}', style: const TextStyle(fontSize: 15)),
          if (e.command.isNotEmpty) Text('보냄: ${e.command}'),
          if (e.raw.isNotEmpty) Text('AI: ${e.raw}', style: const TextStyle(fontSize: 12)),
          if (e.ok != null)
            Text(
              '답: ${e.reply}',
              style: TextStyle(color: e.ok! ? Colors.lightGreenAccent : Colors.orangeAccent),
            ),
          Text(
            'STT ${e.sttMs}ms · 말 ${e.audioMs}ms'
            '${e.totalMs > 0 ? ' · 전체 ${e.totalMs}ms' : ''}',
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}
