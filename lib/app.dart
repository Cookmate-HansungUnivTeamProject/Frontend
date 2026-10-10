import 'package:flutter/material.dart';

import 'models/order.dart';
import 'screens/home_screen.dart';
import 'screens/order_screen.dart';
import 'theme/app_theme.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  late List<Order> _orders;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _orders = [
      Order(
        id: 'LMDJK',
        menuName: '[1.5인] 구이삼겹 김치찜',
        quantity: 1,
        request: '맵게 해주세요',
        status: OrderStatus.waiting,
        orderedAt: now.subtract(const Duration(minutes: 5)),
      ),
      Order(
        id: 'PZQWT',
        menuName: '[1.5인] 직화진짜스팸구이 김치찜',
        quantity: 1,
        request: '요청사항 없음',
        status: OrderStatus.waiting,
        orderedAt: now.subtract(const Duration(minutes: 3)),
      ),
      Order(
        id: 'CJGK3',
        menuName: '[2.5인] 풍족한 삼겹 김치찜',
        quantity: 2,
        request: '없음',
        status: OrderStatus.inProgress,
        orderedAt: now.subtract(const Duration(minutes: 22)),
        acceptedAt: now.subtract(const Duration(minutes: 16)),
      ),
      Order(
        id: 'ABE9H',
        menuName: '[1.5인] 구이삼겹 김치찜',
        quantity: 1,
        request: '없음',
        status: OrderStatus.inProgress,
        orderedAt: now.subtract(const Duration(minutes: 17)),
        acceptedAt: now.subtract(const Duration(minutes: 12)),
        riderRequested: true,
      ),
      Order(
        id: 'CJGK3-C',
        menuName: '[2.5인] 풍족한 삼겹 김치찜',
        quantity: 1,
        request: '없음',
        status: OrderStatus.completed,
        orderedAt: now.subtract(const Duration(hours: 1)),
        completedAt: DateTime(now.year, now.month, now.day, 9, 37),
      ),
      Order(
        id: 'HU042',
        menuName: '[1.5인] 진짜스팸 김치찜',
        quantity: 1,
        request: '마정왕 나홀로 돼지고기 김치찌개',
        status: OrderStatus.completed,
        orderedAt: now.subtract(const Duration(hours: 2)),
        completedAt: DateTime(now.year, now.month, now.day, 9, 12),
      ),
    ];
  }

  void _selectDestination(int index) {
    if (index > 1 || index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  void _updateOrder(Order updatedOrder) {
    setState(() {
      final index = _orders.indexWhere((order) => order.id == updatedOrder.id);
      if (index != -1) _orders[index] = updatedOrder;
    });
  }

  void _removeOrder(String orderId) {
    setState(() => _orders.removeWhere((order) => order.id == orderId));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '이음',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: _selectedIndex == 0
          ? HomeScreen(
              orders: _orders,
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectDestination,
              onOpenOrders: () => _selectDestination(1),
            )
          : OrderScreen(
              orders: _orders,
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectDestination,
              onOrderUpdated: _updateOrder,
              onOrderRemoved: _removeOrder,
            ),
    );
  }
}
