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

extension FulfillmentTypeX on FulfillmentType {
  String get label {
    switch (this) {
      case FulfillmentType.delivery:
        return 'Delivery';
      case FulfillmentType.pickup:
        return 'Pickup';
      case FulfillmentType.scheduled:
        return 'Scheduled Delivery';
    }
  }

  /// Wire value expected by `POST /orders/checkout` (`delivery_method`).
  String get key {
    switch (this) {
      case FulfillmentType.delivery:
        return 'delivery';
      case FulfillmentType.pickup:
        return 'pickup';
      case FulfillmentType.scheduled:
        return 'scheduled_delivery';
    }
  }
}

FulfillmentType fulfillmentTypeFromKey(String key) =>
    FulfillmentType.values.firstWhere((e) => e.key == key,
        orElse: () => FulfillmentType.delivery);

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

  /// Wire value expected by `POST /orders/checkout` (`payment_method`).
  String get key {
    switch (this) {
      case PaymentMethod.cashOnDelivery:
        return 'cash_on_delivery';
      case PaymentMethod.cashOnPickup:
        return 'cash_on_pickup';
    }
  }
}

PaymentMethod paymentMethodFromKey(String key) =>
    PaymentMethod.values.firstWhere((e) => e.key == key,
        orElse: () => PaymentMethod.cashOnDelivery);

OrderStatus orderStatusFromKey(String key) => OrderStatus.values
    .firstWhere((e) => e.key == key, orElse: () => OrderStatus.pending);

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
    this.cancellationReason = '',
    this.discount = 0,
  });

  String cancellationReason;
  double discount;

  double get itemsTotal => items.fold(0, (sum, i) => sum + i.subtotal);
  double get grandTotal {
    final raw = itemsTotal + deliveryFee - discount;
    return raw < 0 ? 0 : raw;
  }

  bool get isActive => ![
        OrderStatus.completed,
        OrderStatus.cancelled,
        OrderStatus.delivered,
      ].contains(status);

  /// Builds an order from `GET /orders/my-orders` / `GET /orders/{id}` /
  /// the checkout response. [vendorName]/[vendorLogoUrl] are resolved by
  /// the caller (the API payload does not include vendor details).
  factory CustomerOrder.fromApi(
    Map<String, dynamic> json, {
    String vendorName = '',
    String vendorLogoUrl = '',
  }) {
    final items = (json['items'] as List? ?? [])
        .map((e) {
          final m = e as Map<String, dynamic>;
          final optionLabels = <String>[];
          final selected = m['selected_options'];
          if (selected is Map) {
            selected.forEach((group, choices) {
              if (choices is List && choices.isNotEmpty) {
                optionLabels.add([group.toString(), ...choices.map((c) => c.toString())].join(': '));
              }
            });
          }
          return OrderLineItem(
            foodName: m['item_name'] as String? ?? '',
            quantity: (m['quantity'] as num?)?.toInt() ?? 1,
            unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0,
            optionLabels: optionLabels,
            specialInstructions: m['special_instructions'] as String? ?? '',
          );
        })
        .toList();

    return CustomerOrder(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String? ?? '',
      vendorId: json['vendor_id'] as String? ?? '',
      vendorName: vendorName,
      vendorLogoUrl: vendorLogoUrl,
      items: items,
      status: orderStatusFromKey(json['status'] as String? ?? 'pending'),
      fulfillmentType:
          fulfillmentTypeFromKey(json['delivery_method'] as String? ?? 'delivery'),
      placedAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      scheduledFor: DateTime.tryParse(json['scheduled_for']?.toString() ?? ''),
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      paymentMethod:
          paymentMethodFromKey(json['payment_method'] as String? ?? 'cash_on_delivery'),
      deliveryAddress: json['delivery_address'] as String? ?? '',
      destinationLat: (json['delivery_latitude'] as num?)?.toDouble(),
      destinationLng: (json['delivery_longitude'] as num?)?.toDouble(),
      cancellationReason: json['cancellation_reason'] as String? ?? '',
    );
  }
}
