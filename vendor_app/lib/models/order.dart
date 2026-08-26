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

  /// The next logical status a vendor can move an order to. Pickup orders
  /// skip the delivery-tracking flow entirely (ready → collected =
  /// completed), matching the backend's guarded transitions.
  OrderStatus? nextFor(FulfillmentType fulfillmentType) {
    switch (this) {
      case OrderStatus.pending:
        return OrderStatus.accepted;
      case OrderStatus.accepted:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.ready;
      case OrderStatus.ready:
        return fulfillmentType == FulfillmentType.pickup
            ? OrderStatus.completed
            : OrderStatus.outForDelivery;
      case OrderStatus.outForDelivery:
        return OrderStatus.delivered;
      case OrderStatus.delivered:
        return OrderStatus.completed;
      case OrderStatus.completed:
      case OrderStatus.cancelled:
        return null;
    }
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
  final String orderNumber;

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
    this.orderNumber = '',
  });

  double get itemsTotal => items.fold(0, (sum, i) => sum + i.subtotal);
  double get grandTotal => itemsTotal + deliveryFee;

  static OrderStatus _statusFromKey(String? key) =>
      OrderStatus.values.firstWhere(
        (s) => s.key == key,
        orElse: () => OrderStatus.pending,
      );

  static FulfillmentType _fulfillmentFromKey(String? key) {
    switch (key) {
      case 'pickup':
        return FulfillmentType.pickup;
      case 'scheduled_delivery':
        return FulfillmentType.scheduled;
      default:
        return FulfillmentType.delivery;
    }
  }

  /// Maps the backend's OrderOut (vendor inbox shape, snake_case).
  factory VendorOrder.fromApi(Map<String, dynamic> json) {
    DateTime? parseDate(String? raw) =>
        raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    return VendorOrder(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? 'Customer',
      customerMobile: json['customer_mobile'] as String? ?? '',
      deliveryAddress: json['delivery_address'] as String? ?? '',
      customerLat: (json['delivery_latitude'] as num?)?.toDouble(),
      customerLng: (json['delivery_longitude'] as num?)?.toDouble(),
      items: [
        for (final item in (json['items'] as List?) ?? [])
          OrderLineItem(
            foodName: (item as Map<String, dynamic>)['item_name'] as String? ?? '',
            quantity: item['quantity'] as int? ?? 1,
            price: (item['unit_price'] as num?)?.toDouble() ?? 0,
            addons: [
              for (final choices
                  in ((item['selected_options'] as Map?)?.cast<String, dynamic>() ?? const {})
                      .values)
                ...((choices as List?)?.cast<String>() ?? const []),
            ],
            specialInstructions:
                item['special_instructions'] as String? ?? '',
          ),
      ],
      status: _statusFromKey(json['status'] as String?),
      fulfillmentType: _fulfillmentFromKey(json['delivery_method'] as String?),
      placedAt: parseDate(json['created_at'] as String?) ?? DateTime.now(),
      scheduledFor: parseDate(json['scheduled_for'] as String?),
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
      paymentMethod: paymentLabel(json['payment_method'] as String?),
      notes: json['special_instructions'] as String? ?? '',
    );
  }

  /// Human label for every PaymentMethod the backend can send.
  static String paymentLabel(String? key) {
    switch (key) {
      case 'cash_on_pickup':
        return 'Cash on Pickup';
      case 'gcash':
        return 'GCash';
      case 'maya':
        return 'Maya';
      case 'credit_card':
        return 'Credit/Debit Card';
      case 'bank_transfer':
        return 'Bank Transfer';
      default:
        return 'Cash on Delivery';
    }
  }
}