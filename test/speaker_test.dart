// 오르보의 답 읽기(TTS). 폰 TTS 엔진 대신 가짜를 써서 마이크·폰 없이 돈다.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/speaker.dart';

/// 폰 TTS 대신 쓰는 가짜. 읽은 글자를 모아 두고, [hang]이면 stop()까지 끝나지 않는다.
class FakeTts implements TtsBackend {
  FakeTts({this.available = true, this.hang = false});

  bool available;
  final bool hang;
  final prepared = <String>[];
  final spoken = <String>[];
  int stops = 0;
  Completer<void>? _current;

  @override
  Future<bool> prepare(String language) async {
    prepared.add(language);
    return available;
  }

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    if (!hang) return Future<void>.value();
    return (_current = Completer<void>()).future;
  }

  @override
  Future<void> stop() async {
    stops++;
    _current?.complete();
    _current = null;
  }
}

void main() {
  test('spokenText drops addresses in parentheses and URLs', () {
    expect(
      spokenText('서버에 연결할 수 없어요 (http://127.0.0.1:8000)'),
      '서버에 연결할 수 없어요',
    );
    expect(spokenText('  1번 가스레인지를 켰어요.  '), '1번 가스레인지를 켰어요.');
    expect(spokenText('주소는 http://10.0.2.2:8000 이에요'), '주소는 이에요');
    expect(spokenText('(http://test)'), '');
  });

  test('Speaker prepares Korean once and reads the cleaned reply', () async {
    final tts = FakeTts();
    final speaker = Speaker(backend: tts);
    await speaker.say('후드를 켰어요.');
    await speaker.say('서버 오류 (500)');
    await speaker.say('   ');
    expect(tts.prepared, ['ko-KR']);
    expect(tts.spoken, ['후드를 켰어요.', '서버 오류']);
    expect(speaker.problem, isEmpty);
    expect(speaker.speaking, isFalse);
  });

  test('Without a Korean voice it stays quiet and tries again later', () async {
    final tts = FakeTts(available: false);
    final speaker = Speaker(backend: tts);
    await speaker.say('후드를 켰어요.');
    expect(tts.spoken, isEmpty);
    expect(speaker.problem, contains('한국어 TTS'));
    tts.available = true; // 폰 설정에서 한국어 음성을 받은 뒤
    await speaker.say('후드를 켰어요.');
    expect(tts.prepared, ['ko-KR', 'ko-KR']);
    expect(tts.spoken, ['후드를 켰어요.']);
    expect(speaker.problem, isEmpty);
  });

  test('say() waits until reading ends, and stop() ends it', () async {
    final tts = FakeTts(hang: true);
    final speaker = Speaker(backend: tts);
    var done = false;
    final saying = speaker.say('모든 기기를 켤까요?').then((_) => done = true);
    await Future<void>.delayed(Duration.zero);
    expect(speaker.speaking, isTrue);
    expect(done, isFalse);
    await speaker.stop();
    await saying;
    expect(done, isTrue);
    expect(speaker.speaking, isFalse);
    expect(tts.stops, 1);
  });

  test('A stuck TTS engine is stopped after the time limit', () async {
    final tts = FakeTts(hang: true);
    final speaker = Speaker(
      backend: tts,
      limit: (_) => const Duration(milliseconds: 20),
    );
    await speaker.say('후드를 켰어요.');
    expect(tts.stops, 1);
    expect(speaker.speaking, isFalse);
  });

  test('Default time limit grows with the text and stops at 30 seconds', () {
    expect(defaultSpeakLimit('네'), const Duration(milliseconds: 3250));
    expect(defaultSpeakLimit('가' * 1000), const Duration(seconds: 30));
  });
}
