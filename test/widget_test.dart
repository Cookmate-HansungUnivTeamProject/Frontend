import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/src/store.dart';
import 'package:frontend/src/voice.dart';

void main() {
  testWidgets('Profile opens settings; voice overlays every destination', (
    tester,
  ) async {
    final store = KitchenStore(tick: false);
    final voice = VoiceController();
    await tester.pumpWidget(
      MyApp(store: store, voice: voice, showSplash: false),
    );
    await tester.tap(find.byKey(const Key('profile')));
    await tester.pumpAndSettle();
    expect(find.text('나에게 맞는 주방으로'), findsOneWidget);
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
  testWidgets('Device power and timer remain in sync across tabs', (
    tester,
  ) async {
    final store = KitchenStore(tick: false);
    final voice = VoiceController();
    await tester.pumpWidget(
      MyApp(store: store, voice: voice, showSplash: false),
    );
    await tester.tap(find.byKey(const Key('nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('가스레인지 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(store.devices.first.power, isTrue);
    await tester.ensureVisible(find.text('시작'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작'));
    await tester.pumpAndSettle();
    expect(store.devices.first.running, isTrue);
    await tester.tap(find.byKey(const Key('nav-0')));
    await tester.pumpAndSettle();
    expect(find.text('03:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    voice.dispose();
  });
  testWidgets('Accepting an order moves it to the cooking tab', (tester) async {
    final store = KitchenStore(tick: false);
    final voice = VoiceController();
    await tester.pumpWidget(
      MyApp(store: store, voice: voice, showSplash: false),
    );
    await tester.tap(find.byKey(const Key('nav-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('주문 수락'));
    await tester.pumpAndSettle();
    expect(store.orders.first.status, 1);
    expect(find.text('해당하는 주문이 없습니다'), findsOneWidget);
    await tester.tap(find.text('진행 중'));
    await tester.pumpAndSettle();
    expect(find.text('주문 #152'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    voice.dispose();
  });
  test('Timer uses deadline and pauses on power off', () {
    final store = KitchenStore(tick: false);
    final d = store.devices.first;
    store.adjust(d, -150);
    expect(d.seconds, 30);
    store.start(d);
    d.deadline = DateTime.now().subtract(const Duration(seconds: 1));
    store.refresh();
    expect(d.seconds, 0);
    expect(d.running, isFalse);
    store.start(d);
    store.power(d, false);
    expect(d.running, isFalse);
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
