enum OrderStatus {
  pending,
  accepted,
  preparing,
  ready,
  outForDelivery,
  delivered,
  completed,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get key {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.accepted:
        return 'accepted';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.outForDelivery:
        return 'out_for_delivery';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  /// The next logical status a vendor can move an order to (linear happy path).
  OrderStatus? get next {
    const flow = [
      OrderStatus.pending,
      OrderStatus.accepted,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
      OrderStatus.completed,
    ];
    final i = flow.indexOf(this);
    if (i == -1 || i == flow.length - 1) return null;
    return flow[i + 1];
  }
}

enum FulfillmentType { delivery, pickup, scheduled }

class OrderLineItem {
  final String foodName;
  final int quantity;
  final double price;
  final List<String> addons;
  final String specialInstructions;

  OrderLineItem({
    required this.foodName,
    required this.quantity,
    required this.price,
    this.addons = const [],
    this.specialInstructions = '',
  });

  double get subtotal => price * quantity;
}

class VendorOrder {
  final String id;
  final String customerName;
  final String customerMobile;
  final String deliveryAddress;
  final double? customerLat;
  final double? customerLng;
  final List<OrderLineItem> items;
  OrderStatus status;
  final FulfillmentType fulfillmentType;
  final DateTime placedAt;
  final DateTime? scheduledFor;
  final double deliveryFee;
  final String paymentMethod;
  final String notes; // order-level note, e.g. "Leave at the gate, thanks!"

  VendorOrder({
    required this.id,
    required this.customerName,
    required this.customerMobile,
    required this.deliveryAddress,
    this.customerLat,
    this.customerLng,
    required this.items,
    this.status = OrderStatus.pending,
    this.fulfillmentType = FulfillmentType.delivery,
    required this.placedAt,
    this.scheduledFor,
    this.deliveryFee = 0,
    this.paymentMethod = 'Cash on Delivery',
    this.notes = '',
  });

  double get itemsTotal => items.fold(0, (sum, i) => sum + i.subtotal);
  double get grandTotal => itemsTotal + deliveryFee;
}