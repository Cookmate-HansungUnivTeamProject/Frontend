enum OrderStatus { waiting, inProgress, completed }

class Order {
  const Order({
    required this.id,
    required this.menuName,
    required this.quantity,
    required this.request,
    required this.status,
    required this.orderedAt,
    this.acceptedAt,
    this.completedAt,
    this.riderRequested = false,
  });

  final String id;
  final String menuName;
  final int quantity;
  final String request;
  final OrderStatus status;
  final DateTime orderedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final bool riderRequested;

  Order copyWith({
    OrderStatus? status,
    DateTime? acceptedAt,
    DateTime? completedAt,
    bool? riderRequested,
  }) {
    return Order(
      id: id,
      menuName: menuName,
      quantity: quantity,
      request: request,
      status: status ?? this.status,
      orderedAt: orderedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      riderRequested: riderRequested ?? this.riderRequested,
    );
  }
}
