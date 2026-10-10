import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/order_card.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({
    required this.orders,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onOrderUpdated,
    required this.onOrderRemoved,
    super.key,
  });

  final List<Order> orders;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<Order> onOrderUpdated;
  final ValueChanged<String> onOrderRemoved;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  int _selectedTab = 0;

  static const _statuses = [
    OrderStatus.waiting,
    OrderStatus.inProgress,
    OrderStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final visibleOrders = widget.orders
        .where((order) => order.status == _statuses[_selectedTab])
        .toList();

    return Scaffold(
      bottomNavigationBar: BottomNavBar(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: widget.onDestinationSelected,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '주문',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            _OrderTabs(
              selectedIndex: _selectedTab,
              counts: _statuses
                  .map(
                    (status) => widget.orders
                        .where((order) => order.status == status)
                        .length,
                  )
                  .toList(),
              onSelected: (index) => setState(() => _selectedTab = index),
            ),
            Expanded(
              child: visibleOrders.isEmpty
                  ? const _EmptyOrderList()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                      itemCount: visibleOrders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = visibleOrders[index];
                        return OrderCard(
                          key: ValueKey(order.id),
                          order: order,
                          onReject: () => _confirmReject(order),
                          onAccept: () => _acceptOrder(order),
                          onCallRider: () => _callRider(order),
                          onComplete: () => _completeOrder(order),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReject(Order order) async {
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('주문을 거절할까요?'),
        content: Text('주문 #${order.id}을 목록에서 제거합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            child: const Text('거절'),
          ),
        ],
      ),
    );

    if (shouldReject == true) widget.onOrderRemoved(order.id);
  }

  void _acceptOrder(Order order) {
    widget.onOrderUpdated(
      order.copyWith(
        status: OrderStatus.inProgress,
        acceptedAt: DateTime.now(),
      ),
    );
  }

  void _callRider(Order order) {
    widget.onOrderUpdated(order.copyWith(riderRequested: true));
  }

  void _completeOrder(Order order) {
    widget.onOrderUpdated(
      order.copyWith(
        status: OrderStatus.completed,
        completedAt: DateTime.now(),
      ),
    );
    setState(() => _selectedTab = 2);
  }
}

class _OrderTabs extends StatelessWidget {
  const _OrderTabs({
    required this.selectedIndex,
    required this.counts,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<int> counts;
  final ValueChanged<int> onSelected;

  static const _labels = ['접수 대기', '진행 중', '완료'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: List.generate(_labels.length, (index) {
          final selected = selectedIndex == index;
          final color = selected ? AppColors.orange : AppColors.textSecondary;
          return Expanded(
            child: InkWell(
              key: Key('order-tab-$index'),
              onTap: () => onSelected(index),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _labels[index],
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          height: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.orange
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${counts[index]}',
                            style: TextStyle(
                              color: selected
                                  ? AppColors.background
                                  : AppColors.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 4,
                    color: selected ? AppColors.orange : Colors.transparent,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _EmptyOrderList extends StatelessWidget {
  const _EmptyOrderList();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 46,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 12),
            Text(
              '해당 상태의 주문이 없어요.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
