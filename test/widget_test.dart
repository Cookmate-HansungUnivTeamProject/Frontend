import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app.dart';

void main() {
  testWidgets('홈에서 주문 화면으로 이동하고 주문을 수락한다', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('반가워요! 춘식님!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bottom-nav-1')));
    await tester.pumpAndSettle();

    expect(find.text('접수 대기'), findsOneWidget);
    expect(find.text('주문 수락'), findsWidgets);

    await tester.tap(find.text('주문 수락').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('order-tab-1')));
    await tester.pumpAndSettle();

    expect(find.text('주문 #LMDJK'), findsOneWidget);
  });
}
