import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _items = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home, label: '홈'),
    (
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: '주문',
    ),
    (icon: Icons.kitchen_outlined, selectedIcon: Icons.kitchen, label: '기기'),
    (icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: '설정'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: const BoxDecoration(
          color: AppColors.navigation,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final selected = index == selectedIndex;
            final color = selected ? AppColors.orange : AppColors.textPrimary;
            return Expanded(
              child: InkWell(
                key: Key('bottom-nav-$index'),
                onTap: () => onDestinationSelected(index),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 3,
                      color: selected ? AppColors.orange : Colors.transparent,
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      selected ? item.selectedIcon : item.icon,
                      size: 25,
                      color: color,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
