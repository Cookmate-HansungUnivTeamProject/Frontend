import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.orders,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onOpenOrders,
    super.key,
  });

  final List<Order> orders;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) {
    final recentOrders = orders
        .where((order) => order.status != OrderStatus.completed)
        .take(2)
        .toList();

    return Scaffold(
      bottomNavigationBar: BottomNavBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            const _GreetingHeader(),
            const SizedBox(height: 24),
            const Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.power_settings_new,
                    value: '2개',
                    label: '작동 중인 기기',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.alarm,
                    value: '2개',
                    label: '진행 중인 타이머',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle(title: '진행 중인 타이머'),
            const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(child: _TimerCard()),
                SizedBox(width: 10),
                Expanded(child: _AddTimerCard()),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle(title: '기기 제어'),
            const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(
                  child: _DeviceCard(
                    name: '가스레인지 2',
                    status: '작동 중',
                    detail: '화력 7',
                    icon: Icons.local_fire_department_outlined,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _DeviceCard(
                    name: '환기팬',
                    status: '작동 중',
                    detail: '풍력 약',
                    icon: Icons.air,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: '주문 관리', onTap: onOpenOrders),
            const SizedBox(height: 10),
            if (recentOrders.isEmpty)
              const _EmptyOrdersCard()
            else
              ...recentOrders.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RecentOrderCard(order: order, onTap: onOpenOrders),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '반가워요! 춘식님!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 5),
              const Text(
                '오늘은 조금 추워요!',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: AppColors.textPrimary, width: 1.5),
          ),
          child: const Icon(
            Icons.person,
            size: 30,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: AppColors.orange, size: 20),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                Text(
                  '전체 보기',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 105,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  '전자레인지 1',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13),
                ),
              ),
              Icon(Icons.chevron_right, size: 18),
            ],
          ),
          const Spacer(),
          const Text(
            '04:38',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(
              value: 0.24,
              minHeight: 6,
              backgroundColor: Color(0xFF808080),
              valueColor: AlwaysStoppedAnimation(AppColors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTimerCard extends StatelessWidget {
  const _AddTimerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 105,
      decoration: _cardDecoration(),
      child: const Center(
        child: Icon(Icons.add, color: AppColors.textPrimary, size: 38),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.name,
    required this.status,
    required this.detail,
    required this.icon,
  });

  final String name;
  final String status;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Icon(icon, color: AppColors.orange, size: 15),
              const SizedBox(width: 4),
              Text(
                status,
                style: const TextStyle(
                  color: AppColors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentOrderCard extends StatelessWidget {
  const _RecentOrderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusText = order.status == OrderStatus.waiting
        ? '주문 접수 대기'
        : '라이더 호출 중';
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${order.menuName} × ${order.quantity}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                statusText,
                style: const TextStyle(
                  color: AppColors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyOrdersCard extends StatelessWidget {
  const _EmptyOrdersCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: const Text(
        '진행 중인 주문이 없어요.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(20),
  );
}
