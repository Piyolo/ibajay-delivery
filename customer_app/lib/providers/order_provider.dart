import 'dart:async';
import 'package:flutter/material.dart';
import '../models/cart.dart';
import '../models/order.dart';
import '../models/vendor.dart';

class OrderProvider extends ChangeNotifier {
  final List<CustomerOrder> _orders = [];
  final Map<String, Timer> _trackingTimers = {};

  List<CustomerOrder> get orders => List.unmodifiable(_orders.reversed);
  List<CustomerOrder> get activeOrders => orders.where((o) => o.isActive).toList();
  List<CustomerOrder> get pastOrders => orders.where((o) => !o.isActive).toList();

  CustomerOrder placeOrder({
    required Cart cart,
    required VendorProfile vendor,
    required FulfillmentType fulfillmentType,
    required PaymentMethod paymentMethod,
    required String deliveryAddress,
    double? destinationLat,
    double? destinationLng,
    DateTime? scheduledFor,
  }) {
    final items = cart.items
        .map((ci) => OrderLineItem(
              foodName: ci.foodItem.name,
              quantity: ci.quantity,
              unitPrice: ci.unitPrice,
              optionLabels: ci.selectedOptions.expand((o) => o.choices.map((c) => c.label)).toList(),
              specialInstructions: ci.specialInstructions,
            ))
        .toList();

    final distanceFee = fulfillmentType == FulfillmentType.pickup
        ? 0.0
        : vendor.deliverySettings.baseDeliveryFee;

    final order = CustomerOrder(
      id: 'o_${DateTime.now().millisecondsSinceEpoch}',
      orderNumber:
          'ORD-${DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '')}-${(1000 + _orders.length)}',
      vendorId: vendor.id,
      vendorName: vendor.storeName,
      vendorLogoUrl: vendor.logoUrl,
      items: items,
      status: OrderStatus.pending,
      fulfillmentType: fulfillmentType,
      placedAt: DateTime.now(),
      scheduledFor: scheduledFor,
      deliveryFee: distanceFee,
      paymentMethod: paymentMethod,
      deliveryAddress: fulfillmentType == FulfillmentType.pickup ? vendor.address : deliveryAddress,
      vendorLat: vendor.latitude,
      vendorLng: vendor.longitude,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
    );

    _orders.add(order);
    notifyListeners();
    _simulateVendorProgress(order);
    return order;
  }

  /// Demo-only: advances the order through the same status flow the real
  /// vendor app drives, so the tracking screen has something to show.
  void _simulateVendorProgress(CustomerOrder order) {
    const flow = [
      OrderStatus.accepted,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ];
    int step = 0;
    _trackingTimers[order.id]?.cancel();
    _trackingTimers[order.id] = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (step >= flow.length || order.fulfillmentType == FulfillmentType.pickup && flow[step] == OrderStatus.outForDelivery) {
        if (order.fulfillmentType == FulfillmentType.pickup) {
          order.status = OrderStatus.ready;
          notifyListeners();
        }
        timer.cancel();
        return;
      }
      order.status = flow[step];
      step++;
      notifyListeners();
      if (order.status == OrderStatus.delivered) {
        timer.cancel();
      }
    });
  }

  CustomerOrder? byId(String id) {
    try {
      return _orders.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  void cancelOrder(String orderId, String reason) {
    final order = byId(orderId);
    if (order == null) return;
    order.status = OrderStatus.cancelled;
    _trackingTimers[orderId]?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _trackingTimers.values) {
      t.cancel();
    }
    super.dispose();
  }
}
