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

  /// Rough progress (0-1) for a stepper/progress bar on the tracking screen.
  double get progress {
    const flow = [
      OrderStatus.pending,
      OrderStatus.accepted,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ];
    final i = flow.indexOf(this);
    if (i == -1) return 1;
    return (i + 1) / flow.length;
  }
}

enum FulfillmentType { delivery, pickup, scheduled }

enum PaymentMethod { cashOnDelivery, cashOnPickup }

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cashOnDelivery:
        return 'Cash on Delivery';
      case PaymentMethod.cashOnPickup:
        return 'Cash on Pickup';
    }
  }
}

class OrderLineItem {
  final String foodName;
  final int quantity;
  final double unitPrice;
  final List<String> optionLabels;
  final String specialInstructions;

  OrderLineItem({
    required this.foodName,
    required this.quantity,
    required this.unitPrice,
    this.optionLabels = const [],
    this.specialInstructions = '',
  });

  double get subtotal => unitPrice * quantity;
}

class CustomerOrder {
  final String id;
  final String orderNumber;
  final String vendorId;
  final String vendorName;
  final String vendorLogoUrl;
  final List<OrderLineItem> items;
  OrderStatus status;
  final FulfillmentType fulfillmentType;
  final DateTime placedAt;
  final DateTime? scheduledFor;
  final double deliveryFee;
  final PaymentMethod paymentMethod;
  final String deliveryAddress;
  double? vendorLat;
  double? vendorLng;
  double? destinationLat;
  double? destinationLng;

  CustomerOrder({
    required this.id,
    required this.orderNumber,
    required this.vendorId,
    required this.vendorName,
    this.vendorLogoUrl = '',
    required this.items,
    this.status = OrderStatus.pending,
    this.fulfillmentType = FulfillmentType.delivery,
    required this.placedAt,
    this.scheduledFor,
    this.deliveryFee = 0,
    this.paymentMethod = PaymentMethod.cashOnDelivery,
    this.deliveryAddress = '',
    this.vendorLat,
    this.vendorLng,
    this.destinationLat,
    this.destinationLng,
  });

  double get itemsTotal => items.fold(0, (sum, i) => sum + i.subtotal);
  double get grandTotal => itemsTotal + deliveryFee;

  bool get isActive => ![
        OrderStatus.completed,
        OrderStatus.cancelled,
        OrderStatus.delivered,
      ].contains(status);
}
