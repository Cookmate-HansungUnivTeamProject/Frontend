import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    required this.order,
    this.onReject,
    this.onAccept,
    this.onCallRider,
    this.onComplete,
    super.key,
  });

  final Order order;
  final VoidCallback? onReject;
  final VoidCallback? onAccept;
  final VoidCallback? onCallRider;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '주문 #${order.id}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              if (order.status == OrderStatus.waiting)
                Text(
                  _waitingTime(order.orderedAt),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${order.menuName} × ${order.quantity}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 7),
          Text(
            '요청사항: ${order.request}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          _TimeInformation(order: order),
          if (order.status != OrderStatus.completed) ...[
            const SizedBox(height: 13),
            _buildActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    if (order.status == OrderStatus.waiting) {
      return Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: '거절',
              backgroundColor: const Color(0xFFBDBDBD),
              foregroundColor: const Color(0xFF555555),
              onPressed: onReject,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _ActionButton(
              label: '주문 수락',
              backgroundColor: AppColors.orange,
              onPressed: onAccept,
            ),
          ),
        ],
      );
    }

    if (!order.riderRequested) {
      return _ActionButton(
        label: '라이더 호출',
        backgroundColor: AppColors.teal,
        onPressed: onCallRider,
      );
    }

    return _ActionButton(
      label: '조리 완료',
      backgroundColor: AppColors.orange,
      onPressed: onComplete,
    );
  }

  String _waitingTime(DateTime orderedAt) {
    final minutes = DateTime.now().difference(orderedAt).inMinutes;
    if (minutes <= 0) return '방금 전';
    return '$minutes분 전';
  }
}

class _TimeInformation extends StatelessWidget {
  const _TimeInformation({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    String text;
    if (order.status == OrderStatus.waiting) {
      text = '주문 후 ${DateTime.now().difference(order.orderedAt).inMinutes}분 경과';
    } else if (order.status == OrderStatus.inProgress) {
      final startedAt = order.acceptedAt ?? order.orderedAt;
      text = '접수 ${DateTime.now().difference(startedAt).inMinutes}분 경과';
    } else {
      text = '조리 완료 시각: ${_formatTime(order.completedAt ?? DateTime.now())}';
    }

    return Row(
      children: [
        const Icon(Icons.schedule, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
    this.foregroundColor = Colors.white,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
