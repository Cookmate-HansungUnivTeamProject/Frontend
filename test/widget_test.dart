import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/src/api.dart';
import 'package:frontend/src/store.dart';
import 'package:frontend/src/voice.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 백엔드처럼 답하는 가짜 서버. 규칙은 백엔드(app/core.py)와 같게, 앱이 쓰는 만큼만 흉내 낸다.
class FakeBackend {
  FakeBackend() {
    const deviceNames = {
      'gas_1': '1번 가스레인지',
      'gas_2': '2번 가스레인지',
      'hood': '후드',
      'fan': '환풍기',
      'microwave': '전자레인지',
    };
    const timerNames = {
      'gas_1': '1번 가스레인지 타이머',
      'gas_2': '2번 가스레인지 타이머',
      'shared': '공용 타이머',
      'microwave': '전자레인지 타이머',
    };
    for (final e in deviceNames.entries) {
      devices[e.key] = {'id': e.key, 'name': e.value, 'on': false, 'level': 0};
    }
    for (final e in timerNames.entries) {
      timers[e.key] = {
        'id': e.key,
        'name': e.value,
        'device': e.key == 'shared' ? '' : e.key,
        'set_sec': 0,
        'remaining_sec': 0,
        'state': 'idle',
      };
    }
    orders.add(order(1, 1, '[1.5인] 구이삼겹 김치찜', 'new', '덜맵게 해주세요'));
    orders.add(order(2, 2, '[2.5인] 풍족한 삼겹 김치찜', 'accepted', '없음'));
  }

  final now = DateTime.now().millisecondsSinceEpoch;
  final devices = <String, Map<String, dynamic>>{};
  final timers = <String, Map<String, dynamic>>{};
  final orders = <Map<String, dynamic>>[];
  final requests = <http.Request>[];
  double fridge = 3.5;

  late final client = MockClient(handle);

  Map<String, dynamic> order(
    int id,
    int slot,
    String menu,
    String status,
    String request,
  ) => {
    'id': id,
    'slot': slot,
    'menu': menu,
    'qty': 1,
    'request': request,
    'photo': '',
    'status': status,
    'created_at': now - 3 * 60000,
    'accepted_at': 0,
    'done_at': 0,
    'rider_at': 0,
  };

  Map<String, dynamic> state() => {
    'server_time': now,
    'devices': devices.values.toList(),
    'timers': timers.values.toList(),
    'orders': orders,
    'env': {'kitchen_temp': 26.0, 'fridge_temp': fridge},
    'alerts': [
      if (fridge > 5)
        {'kind': 'fridge_temp', 'target': 'fridge', 'message': '냉장고 온도가 높아요.'},
    ],
    'last_command': {'seq': 0, 'text': '', 'reply': '', 'ts': 0},
  };

  /// 앱이 보낸 POST를 '경로 바디' 문자열로.
  List<String> get posts => [
    for (final r in requests)
      if (r.method == 'POST') '${r.url.path} ${r.body}'.trim(),
  ];

  http.Response reply(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  http.Response invalid(String msg) => reply({
    'detail': [
      {'type': 'value_error', 'msg': msg},
    ],
  }, 422);

  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    // 서버처럼: 바디가 있는데 JSON 헤더가 없으면 422
    final type = r.headers['content-type'] ?? '';
    if (r.body.isNotEmpty && !type.startsWith('application/json')) {
      return invalid('Input should be a valid dictionary');
    }
    final body = r.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(r.body) as Map<String, dynamic>;
    final p = r.url.pathSegments; // [api, kind, id, action]
    if (r.method == 'GET' && r.url.path == '/api/state') return reply(state());
    if (p.length == 4 && p[1] == 'devices') return device(p[2], p[3], body);
    if (p.length == 4 && p[1] == 'timers') return timer(p[2], p[3], body);
    if (p.length == 4 && p[1] == 'orders') {
      return orderAction(int.parse(p[2]), p[3]);
    }
    return reply({'detail': 'Not Found'}, 404);
  }

  http.Response device(String id, String action, Map<String, dynamic> body) {
    final d = devices[id];
    if (d == null) return reply({'detail': '없는 기기예요.'}, 404);
    if (action == 'power') {
      final on = body['on'] as bool;
      if (id == 'microwave') {
        // 전자레인지는 타이머로만 켠다. 끄면 타이머도 끈다.
        final active = timers['microwave']!['state'] != 'idle';
        if (!on && active) stopTimer('microwave');
        return reply({'ok': !on && active, 'device': d});
      }
      final changed = d['on'] != on;
      d['on'] = on;
      d['level'] = on ? (id.startsWith('gas') ? 2 : 0) : 0;
      return reply({'ok': changed, 'device': d});
    }
    if (action == 'level') {
      final level = body['level'];
      if (!id.startsWith('gas')) return invalid('$id는 세기를 바꿀 수 없어요.');
      if (level is! int || level < 1 || level > 3) {
        return invalid('화력은 1~3이에요');
      }
      if (d['on'] != true) return reply({'ok': false, 'device': d});
      d['level'] = level;
      return reply({'ok': true, 'device': d});
    }
    return reply({'detail': 'Not Found'}, 404);
  }

  void stopTimer(String id) {
    timers[id]!
      ..['set_sec'] = 0
      ..['remaining_sec'] = 0
      ..['state'] = 'idle';
    if (id == 'microwave') devices['microwave']!['on'] = false;
  }

  http.Response timer(String id, String action, Map<String, dynamic> body) {
    final t = timers[id];
    if (t == null) return reply({'detail': '없는 타이머예요.'}, 404);
    if (action == 'start') {
      final sec = body['sec'];
      if (sec is! int || sec < 30 || sec > 300 || sec % 30 != 0) {
        return invalid('타이머는 5분까지 30초 단위로 맞출 수 있어요.');
      }
      t
        ..['set_sec'] = sec
        ..['remaining_sec'] = sec
        ..['state'] = 'running';
      if (id == 'microwave') devices['microwave']!['on'] = true;
      return reply({'ok': true, 'timer': t});
    }
    if (action == 'stop') {
      stopTimer(id);
      return reply({'ok': true, 'timer': t});
    }
    return reply({'detail': 'Not Found'}, 404);
  }

  http.Response orderAction(int id, String action) {
    Map<String, dynamic>? o;
    for (final x in orders) {
      if (x['id'] == id) o = x;
    }
    if (o == null) return reply({'detail': '없는 주문이에요.'}, 404);
    final status = o['status'];
    if (action == 'accept' || action == 'reject') {
      if (status != 'new') return reply({'detail': '이미 처리한 주문이에요.'}, 409);
      o['status'] = action == 'accept' ? 'accepted' : 'rejected';
    } else if (action == 'complete') {
      if (status == 'new') return reply({'detail': '아직 받지 않은 주문이에요.'}, 409);
      if (status != 'accepted') {
        return reply({'detail': '이미 처리한 주문이에요.'}, 409);
      }
      o['status'] = 'done';
    } else {
      return reply({'detail': 'Not Found'}, 404);
    }
    return reply(o);
  }
}

KitchenStore storeFor(FakeBackend fake) => KitchenStore(
  api: KitchenApi(baseUrl: 'http://test', client: fake.client),
  poll: false,
)..apply(fake.state());

void main() {
  testWidgets('Profile opens settings; voice overlays every destination', (
    tester,
  ) async {
    final store = storeFor(FakeBackend());
    final voice = VoiceController();
    await tester.pumpWidget(
      MyApp(store: store, voice: voice, showSplash: false),
    );
    await tester.tap(find.byKey(const Key('profile')));
    await tester.pumpAndSettle();
    expect(find.text('나에게 맞는 주방으로'), findsOneWidget);
    expect(find.text('http://test'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('notification-setting')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.notifications, isFalse);
    voice.receive({'type': 'wake'});
    voice.receive({'type': 'partial', 'text': '오르보, 타이머 켜줘'});
    await tester.pump();
    expect(find.text('오르보, 타이머 켜줘'), findsOneWidget);
    for (final label in ['기기', '타이머', '주문', '홈']) {
      await tester.tap(
        find.byKey(Key('nav-${['홈', '주문', '기기', '타이머'].indexOf(label)}')),
      );
      await tester.pumpAndSettle();
      expect(find.text('오르보, 타이머 켜줘'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    voice.hide();
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    voice.dispose();
  });

  testWidgets('Unavailable logout is presented as a demo action', (
    tester,
  ) async {
    final store = storeFor(FakeBackend());
    final voice = VoiceController();
    await tester.pumpWidget(
      MyApp(store: store, voice: voice, showSplash: false),
    );
    await tester.tap(find.byKey(const Key('profile')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('logout-setting')),
      250,
    );
    // 스크롤한 위치는 다음 프레임에 화면에 반영된다. 그 전에 누르면 아래 탭 바를 누르게 된다.
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout-setting')));
    await tester.pump();
    expect(find.text('로그인 기능 연결 후 사용할 수 있어요.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    voice.dispose();
  });

  testWidgets('Server address can be changed in settings', (tester) async {
    final fake = FakeBackend();
    final store = storeFor(fake);
    final voice = VoiceController();
    await tester.pumpWidget(
      MyApp(store: store, voice: voice, showSplash: false),
    );
    await tester.tap(find.byKey(const Key('profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('바꾸기'));
    await tester.pumpAndSettle();
    expect(find.text('서버 주소'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '10.0.2.2:8000/');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(store.apiBase, 'http://10.0.2.2:8000');
    expect(
      fake.requests.last.url.toString(),
      'http://10.0.2.2:8000/api/state',
    );
    expect(store.connected, isTrue);
    expect(find.text('http://10.0.2.2:8000'), findsOneWidget);
    expect(find.text('연결됨'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    voice.dispose();
  });

  testWidgets('Device power, flame and timer go through the server', (
    tester,
  ) async {
    final fake = FakeBackend();
    final store = storeFor(fake);
    final voice = VoiceController();
    await tester.pumpWidget(
      MyApp(store: store, voice: voice, showSplash: false),
    );
    await tester.tap(find.byKey(const Key('nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('냉장고'), findsOneWidget);
    expect(find.text('3.5°C'), findsOneWidget);
    // 꺼진 가스레인지(서버 level 0)의 상세 화면도 슬라이더가 깨지지 않아야 한다
    await tester.tap(find.text('1번 가스레인지'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(fake.posts, contains('/api/devices/gas_1/power {"on":true}'));
    expect(store.device('gas_1').power, isTrue);
    expect(store.device('gas_1').level, 2);
    await tester.ensureVisible(find.text('시작'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작'));
    await tester.pumpAndSettle();
    expect(fake.posts, contains('/api/timers/gas_1/start {"sec":180}'));
    expect(store.device('gas_1').running, isTrue);
    await tester.tap(find.byKey(const Key('nav-0')));
    await tester.pumpAndSettle();
    expect(find.text('03:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    voice.dispose();
  });

  testWidgets('Order buttons go through the server', (tester) async {
    final fake = FakeBackend();
    final store = storeFor(fake);
    final voice = VoiceController();
    await tester.pumpWidget(
      MyApp(store: store, voice: voice, showSplash: false),
    );
    await tester.tap(find.byKey(const Key('nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('주문 #1'), findsOneWidget);
    expect(find.text('3분 전'), findsOneWidget);
    await tester.tap(find.text('주문 수락'));
    await tester.pumpAndSettle();
    expect(fake.posts, contains('/api/orders/1/accept'));
    expect(find.text('해당하는 주문이 없습니다'), findsOneWidget);
    await tester.tap(find.text('진행 중'));
    await tester.pumpAndSettle();
    expect(find.text('주문 #1'), findsOneWidget);
    expect(find.text('주문 #2'), findsOneWidget);
    await tester.tap(find.text('조리 완료').first);
    await tester.pumpAndSettle();
    expect(fake.posts, contains('/api/orders/1/complete'));
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();
    expect(find.text('조리가 완료되었습니다'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    voice.dispose();
  });

  test('POST sends JSON headers and an integer flame level', () async {
    final fake = FakeBackend();
    final store = storeFor(fake);
    final gas = store.device('gas_1');
    await store.power(gas, true);
    await store.setLevel(gas, 3);
    final posts = fake.requests.where((r) => r.method == 'POST').toList();
    expect(posts, hasLength(2));
    for (final r in posts) {
      expect(r.headers['content-type'], startsWith('application/json'));
    }
    expect(posts.last.body, '{"level":3}');
    expect(gas.level, 3);
    expect(store.notice, isNull);
    store.dispose();
  });

  test('Timer picker stays within 30 seconds to 5 minutes', () {
    final store = storeFor(FakeBackend());
    final d = store.device('shared');
    for (var i = 0; i < 20; i++) {
      store.adjust(d, timerStepSec);
    }
    expect(d.pick, maxTimerSec);
    for (var i = 0; i < 20; i++) {
      store.adjust(d, -timerStepSec);
    }
    expect(d.pick, minTimerSec);
    store.dispose();
  });

  test('Microwave runs by its timer, not by the power switch', () async {
    final fake = FakeBackend();
    final store = storeFor(fake);
    final mw = store.device('microwave');
    await store.power(mw, true);
    expect(fake.posts, isEmpty);
    expect(store.takeNotice(), '전자레인지는 타이머로 돌려요.');
    mw.pick = 90;
    await store.start(mw);
    expect(fake.posts, contains('/api/timers/microwave/start {"sec":90}'));
    expect(mw.power, isTrue);
    expect(mw.running, isTrue);
    await store.power(mw, false);
    expect(mw.power, isFalse);
    expect(mw.timerState, 'idle');
    store.dispose();
  });

  // 타이머가 끝났을 때 전원을 끄는 일은 백엔드가 한다(app/core.py _sync_linked).
  // 백엔드는 끝난 타이머를 ringing(알람)으로 두고 전자레인지 전원을 끈다. 앱은 그 상태를 그대로 보여 준다.
  testWidgets('Finished microwave timer rings while the microwave is off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = FakeBackend();
    fake.timers['microwave']!
      ..['set_sec'] = 90
      ..['remaining_sec'] = 0
      ..['state'] = 'ringing';
    final store = storeFor(fake);
    final voice = VoiceController();
    final mw = store.device('microwave');
    expect(mw.ringing, isTrue);
    expect(mw.power, isFalse);
    expect(mw.statusText, '꺼짐');
    await tester.pumpWidget(
      MyApp(store: store, voice: voice, showSplash: false),
    );
    await tester.tap(find.byKey(const Key('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('시간이 다 됐어요'), findsOneWidget);
    await tester.ensureVisible(find.text('알람 끄기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('알람 끄기'));
    await tester.pumpAndSettle();
    expect(fake.posts, contains('/api/timers/microwave/stop'));
    expect(mw.timerState, 'idle');
    expect(mw.power, isFalse);
    expect(find.text('시간이 다 됐어요'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    voice.dispose();
  });

  test('Shared timer has no power: it rings, then waits again', () async {
    final fake = FakeBackend();
    fake.timers['shared']!
      ..['set_sec'] = 60
      ..['remaining_sec'] = 0
      ..['state'] = 'ringing';
    final store = storeFor(fake);
    final shared = store.device('shared');
    expect(shared.isDevice, isFalse);
    expect(shared.statusText, '알람');
    expect(shared.lit, isTrue);
    await store.stop(shared);
    expect(fake.posts, contains('/api/timers/shared/stop'));
    expect(shared.timerState, 'idle');
    expect(shared.statusText, '대기');
    expect(shared.lit, isFalse);
    store.dispose();
  });

  test('Server refusals become a notice and the state is re-read', () async {
    final fake = FakeBackend();
    final store = storeFor(fake);
    final accepted = store.orders.firstWhere((o) => o.id == 2);
    await store.accept(accepted);
    expect(store.takeNotice(), '이미 처리한 주문이에요.');
    expect(store.orders.firstWhere((o) => o.id == 2).status, 1);
    store.dispose();
  });

  test('Server state maps to the screen', () async {
    final fake = FakeBackend()..fridge = 8;
    fake.timers['gas_2']!
      ..['set_sec'] = 120
      ..['remaining_sec'] = 90
      ..['state'] = 'running';
    fake.orders.add(fake.order(3, 3, '떡볶이', 'rejected', '없음'));
    final store = storeFor(fake);
    final new1 = store.orders.firstWhere((o) => o.id == 1);
    expect(new1.status, 0);
    expect(new1.number, 1);
    expect(new1.items, '[1.5인] 구이삼겹 김치찜 × 1\n요청: 덜맵게 해주세요');
    expect(new1.time, '3분 전');
    expect(store.orders.firstWhere((o) => o.id == 3).status, 3);
    final gas2 = store.device('gas_2');
    expect(gas2.running, isTrue);
    expect(gas2.duration, 120);
    expect(gas2.seconds, inInclusiveRange(89, 90));
    expect(store.fridgeTemp, 8);
    expect(store.fridgeWarning, isTrue);
    expect(store.kitchenTemp, 26);
    store.dispose();
  });

  test('Connection failure is reported, not thrown', () async {
    final store = KitchenStore(
      api: KitchenApi(
        baseUrl: '192.168.0.99:8000/',
        client: MockClient((_) async => throw http.ClientException('down')),
      ),
      poll: false,
    );
    expect(store.apiBase, 'http://192.168.0.99:8000');
    await store.refresh();
    expect(store.connected, isFalse);
    expect(store.error, contains('서버에 연결할 수 없어요'));
    store.dispose();
  });

  test('Voice ignores malformed events and disabled wake events', () async {
    final voice = VoiceController();
    voice.receive('bad');
    voice.receive({'type': 'unknown'});
    expect(voice.visible, isFalse);
    voice.receive({'type': 'wake'});
    expect(voice.visible, isTrue);
    await voice.setEnabled(false);
    voice.receive({'type': 'wake'});
    expect(voice.visible, isFalse);
    voice.dispose();
  });
}
