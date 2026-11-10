// "오르보" 호출어 판정과 음성 명령 요청 모양. 마이크·모델 없이 돈다.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/api.dart';
import 'package:frontend/src/wake_word.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('matchWake', () {
    test('정확히 말하면 호출어를 떼고 명령만 남긴다', () {
      final m = matchWake('오르보, 후드 켜 줘.');
      expect(m.matched, isTrue);
      expect(m.distance, 0);
      expect(m.heard, '오르보');
      expect(m.command, '후드 켜 줘');
    });

    test('호출어만 말하면 명령이 비어 있다', () {
      for (final text in ['오르보', '오르보.', '오르보야', ' 오르보? ']) {
        final m = matchWake(text);
        expect(m.matched, isTrue, reason: text);
        expect(m.command, '', reason: text);
      }
    });

    test('STT가 조금 다르게 적어도 받는다(자모 1개 차이)', () {
      final cases = {
        '올보 후드 켜줘': '올보',
        '오로보 후드 켜줘': '오로보',
        '어르보 후드 켜줘': '어르보',
        '오르버 후드 켜줘': '오르버',
        '오르바, 후드 켜줘': '오르바',
        '오르 보 후드 켜줘': '오르보',
      };
      for (final c in cases.entries) {
        final m = matchWake(c.key);
        expect(m.matched, isTrue, reason: c.key);
        expect(m.distance, lessThanOrEqualTo(1), reason: c.key);
        expect(m.heard, c.value, reason: c.key);
        expect(m.command, '후드 켜줘', reason: c.key);
      }
    });

    test('호출어 뒤의 "야"와 문장부호는 떼고 숫자는 그대로 둔다', () {
      expect(matchWake('오르보야 1번 가스레인지 약불로 켜 줘').command, '1번 가스레인지 약불로 켜 줘');
      expect(matchWake('"오르보!" 환풍기 꺼 줘').command, '환풍기 꺼 줘');
      expect(matchWake('오르보, 3번 주문 접수해 줘?').command, '3번 주문 접수해 줘');
    });

    test('비슷하지만 다른 말이나 중간의 호출어는 받지 않는다', () {
      for (final text in [
        '오르면 돼',
        '올려 줘',
        '오븐 켜 줘',
        '오보 후드 켜 줘', // 자모 2개 차이
        '올봄에 할까',
        '오른쪽 가스레인지',
        '후드 켜 줘',
        '아까 오르보가 말했잖아',
        '오',
        '',
        'hello',
      ]) {
        expect(matchWake(text).matched, isFalse, reason: text);
      }
    });

    test('STT의 전각 문장부호(？ ！ 。 ，)도 일반 문장부호처럼 뗀다', () {
      final m = matchWake('오르보。후드 켜 줘？');
      expect(m.matched, isTrue);
      expect(m.command, '후드 켜 줘');
      expect(matchWake('오르보！').command, '');
      expect(stripSentenceEnd('들려려？'), '들려려');
      expect(normalizePunctuation('후드 켜고，환풍기 꺼 줘。'), '후드 켜고,환풍기 꺼 줘.');
      expect(yesOrNo('응。'), isTrue);
      expect(matchWake('어。').matched, isFalse);
    });

    test('자모 쪼개기와 거리', () {
      expect(toJamo('올보'), ['ㅇ', 'ㅗ', 'ㄹ', 'ㅂ', 'ㅗ']);
      expect(toJamo('오르보'), ['ㅇ', 'ㅗ', 'ㄹ', 'ㅡ', 'ㅂ', 'ㅗ']);
      expect(editDistance(toJamo('올보'), toJamo('오르보')), 1);
      expect(editDistance(toJamo('오보'), toJamo('오르보')), 2);
      expect(editDistance(const [], toJamo('오르보')), 6);
    });
  });

  test('확인 질문 대답(예·아니요)', () {
    for (final text in ['응', '네 켜 줘', '그래.', '어 해줘', '좋아']) {
      expect(yesOrNo(text), isTrue, reason: text);
    }
    for (final text in ['아니', '아니야 됐어', '취소', '하지 마']) {
      expect(yesOrNo(text), isFalse, reason: text);
    }
    expect(yesOrNo('후드 켜 줘'), isNull);
    expect(stripSentenceEnd(' 후드 켜 줘?! '), '후드 켜 줘');
  });

  test('command()는 들은 문장을 JSON으로 보내고 오래 기다린다', () async {
    final sent = <Map<String, dynamic>>[];
    final api = KitchenApi(
      baseUrl: 'http://127.0.0.1:8000',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/commands');
        expect(request.headers['content-type'], startsWith('application/json'));
        sent.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'ok': true,
            'reply': '모든 기기를 켤까요?',
            'needs_input': false,
            'needs_confirm': true,
            'error': '',
            'results': [],
            'raw': '<kitchen_control>(type=2, device=0, power=0)<kitchen_end>',
            'ai_ms': 5900.0,
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final res = await api.command('전부 켜 줘', requestId: 'v1');
    expect(res['needs_confirm'], isTrue);
    await api.command(
      '전부 켜 줘',
      raw: res['raw'] as String,
      confirm: true,
      requestId: 'v1',
    );
    expect(sent, [
      {'text': '전부 켜 줘', 'request_id': 'v1'},
      {
        'text': '전부 켜 줘',
        'raw': '<kitchen_control>(type=2, device=0, power=0)<kitchen_end>',
        'confirm': true,
        'request_id': 'v1',
      },
    ]);
    expect(KitchenApi.commandTimeout, const Duration(seconds: 90));
  });
}
