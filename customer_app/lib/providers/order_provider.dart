import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/cart.dart';
import '../models/order.dart';
import '../models/vendor.dart';
import '../services/api_client.dart';
import 'vendor_provider.dart';

/// Real order lifecycle against `/api/v1/orders`:
///  - [checkout] posts `POST /orders/checkout` (server recomputes prices).
///  - [loadOrders] pulls `GET /orders/my-orders` for history.
///  - [cancelOrder] calls `POST /orders/{id}/cancel`.
///  - [watchOrder] subscribes to `ws /ws/orders/{id}/track` so status
///    changes and GPS pings pushed by the vendor app appear live.
class OrderProvider extends ChangeNotifier {
  OrderProvider({ApiClient? apiClient, VendorProvider? vendors})
      : _client = apiClient ?? ApiClient(),
        _vendors = vendors;

  final ApiClient _client;
  final VendorProvider? _vendors;

  final List<CustomerOrder> _orders = [];
  bool _isLoading = false;

  /// Last network error (load/checkout/cancel) for UI display; null when
  /// the last operation succeeded.
  String? lastError;

  // Live tracking socket for the order currently on screen.
  String? _watchedOrderId;
  WebSocketChannel? _watchChannel;
  StreamSubscription<dynamic>? _watchSub;
  double? riderLat;
  double? riderLng;

  /// Set when the live-tracking socket drops or fails; the tracking screen
  /// shows it instead of pretending pings are still flowing. Null = healthy.
  String? trackingError;

  List<CustomerOrder> get orders => List.unmodifiable(_orders.reversed);
  List<CustomerOrder> get activeOrders => orders.where((o) => o.isActive).toList();
  List<CustomerOrder> get pastOrders => orders.where((o) => !o.isActive).toList();
  bool get isLoading => _isLoading;

  CustomerOrder? byId(String id) {
    try {
      return _orders.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  // ---- Checkout ----

  /// Places a real order via `POST /orders/checkout`. The backend rebuilds
  /// every line from its own food-item table, so only IDs/quantities/
  /// option labels are sent. Throws [ApiException] with a user-friendly
  /// message when the backend rejects it.
  Future<CustomerOrder> checkout({
    required Cart cart,
    required VendorProfile vendor,
    required FulfillmentType fulfillmentType,
    required PaymentMethod paymentMethod,
    required String addressId,
    String deliveryInstructions = '',
    DateTime? scheduledFor,
    String? promoCode,
  }) async {
    lastError = null;

    final payload = {
      'vendor_id': vendor.id,
      'delivery_method': fulfillmentType.key,
      'payment_method': paymentMethod.key,
      'items': cart.items
          .map((ci) => {
                'food_item_id': ci.foodItem.id,
                'quantity': ci.quantity,
                'selected_options': {
                  for (final o in ci.selectedOptions)
                    o.groupName: o.choices.map((c) => c.label).toList(),
                },
                if (ci.specialInstructions.trim().isNotEmpty)
                  'special_instructions': ci.specialInstructions.trim(),
              })
          .toList(),
      if (fulfillmentType != FulfillmentType.pickup) 'address_id': addressId,
      if (fulfillmentType == FulfillmentType.scheduled && scheduledFor != null)
        'scheduled_for': scheduledFor.toIso8601String(),
      if (deliveryInstructions.trim().isNotEmpty)
        'special_instructions': deliveryInstructions.trim(),
      if (promoCode != null && promoCode.trim().isNotEmpty)
        'promo_code': promoCode.trim().toUpperCase(),
    };

    final data = await _client.post('/orders/checkout', body: payload);
    final order = _orderFromApi(data as Map<String, dynamic>);
    _orders.add(order);
    notifyListeners();
    return order;
  }

  /// Pre-checks a promo code at checkout (`POST /orders/validate-promo`).
  /// Returns the discount amount when valid; throws otherwise.
  Future<double> validatePromo({
    required VendorProfile vendor,
    required String code,
    required double subtotal,
  }) async {
    final data = await _client.post('/orders/validate-promo', body: {
      'vendor_id': vendor.id,
      'code': code.trim().toUpperCase(),
      'subtotal': subtotal,
    }) as Map<String, dynamic>;
    if (data['valid'] != true) {
      throw ApiException(data['message'] as String? ?? 'Invalid promo code');
    }
    return (data['discount'] as num?)?.toDouble() ?? 0;
  }

  // ---- History / single order ----

  /// Loads the signed-in customer's order history. Failures keep any
  /// already-loaded orders and surface via [lastError].
  Future<void> loadOrders() async {
    if (_isLoading || _client.authToken == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _client.get('/orders/my-orders') as List;
      _orders
        ..clear()
        ..addAll(data.map((e) => _orderFromApi(e as Map<String, dynamic>)));
      lastError = null;
    } on ApiException catch (e) {
      lastError = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches a single order from the API (used when opening the tracking
  /// screen for an order not yet in memory, e.g. right after login).
  Future<CustomerOrder?> refreshOrder(String id) async {
    try {
      final data = await _client.get('/orders/$id') as Map<String, dynamic>;
      final fresh = _orderFromApi(data);
      final index = _orders.indexWhere((o) => o.id == id);
      if (index >= 0) {
        _orders[index] = fresh;
      } else {
        _orders.add(fresh);
      }
      notifyListeners();
      return fresh;
    } on ApiException {
      return byId(id);
    }
  }

  // ---- Cancellation ----

  /// Cancels server-side (`reason` is a query parameter on the backend),
  /// then reflects the new status locally.
  Future<void> cancelOrder(String orderId, String reason) async {
    await _client.post('/orders/$orderId/cancel', query: {'reason': reason});
    final order = byId(orderId);
    if (order != null) {
      order.status = OrderStatus.cancelled;
      order.cancellationReason = reason;
      notifyListeners();
    }
  }

  // ---- Reviews ----

  /// Whether the customer already reviewed this order.
  Future<bool> hasReview(String orderId) async {
    try {
      await _client.get('/orders/$orderId/review');
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return false;
      rethrow;
    }
  }

  /// Submits the post-delivery rating. Only allowed by the backend once the
  /// order is delivered/completed, one review per order.
  Future<void> submitReview(
    String orderId, {
    required int stars,
    String? comment,
  }) async {
    await _client.post('/orders/$orderId/review', body: {
      'stars': stars,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
  }

  // ---- Live tracking ----

  /// Subscribes to the order's tracking WebSocket — but ONLY while the
  /// order is out for delivery. Ibajay Eats has no fleet of its own: live
  /// location exists solely so the customer can follow the VENDOR's
  /// delivery during an active delivery, and it must not run for orders
  /// sitting in any other state. Safe to call again — the old socket is
  /// closed first.
  void watchOrder(String orderId) {
    stopWatching();
    final token = _client.authToken;
    if (token == null || token.isEmpty) return;

    final order = byId(orderId);
    if (order == null || order.status != OrderStatus.outForDelivery) return;

    final wsScheme =
        _client.baseUrl.startsWith('https') ? 'wss' : 'ws';
    final host = _client.baseUrl
        .replaceFirst('https://', '')
        .replaceFirst('http://', '');
    final uri = Uri.parse('$wsScheme://$host/ws/orders/$orderId/track?token=$token');

    _watchedOrderId = orderId;
    trackingError = null;
    try {
      _watchChannel = WebSocketChannel.connect(uri);
      _watchSub = _watchChannel!.stream.listen(
        _onSocketMessage,
        onError: (_) {
          // Surface the drop instead of leaving a frozen pin that looks
          // alive; the screen offers a retry.
          if (_watchedOrderId == orderId) {
            trackingError = 'Live tracking was interrupted';
            notifyListeners();
          }
        },
        cancelOnError: true,
      );
    } catch (_) {
      // Socket failures degrade gracefully: the tracking screen still
      // shows the last known state, with a retry affordance.
      _watchChannel = null;
      _watchedOrderId = null;
      trackingError = 'Live tracking is unavailable right now';
      notifyListeners();
    }
  }

  void _onSocketMessage(dynamic data) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(data as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = msg['type'] as String?;
    final orderId = _watchedOrderId;
    if (orderId == null) return;

    switch (type) {
      case 'status_update':
        final order = byId(orderId);
        final statusKey = msg['status'] as String?;
        if (order != null && statusKey != null) {
          order.status = orderStatusFromKey(statusKey);
          // The moment the delivery ends, live tracking ends with it.
          if (order.status != OrderStatus.outForDelivery) {
            stopWatching();
          }
          notifyListeners();
        }
      case 'gps_update':
        trackingError = null;
        riderLat = (msg['latitude'] as num?)?.toDouble();
        riderLng = (msg['longitude'] as num?)?.toDouble();
        notifyListeners();
    }
  }

  /// Closes the tracking socket (call from the screen's dispose).
  void stopWatching() {
    _watchSub?.cancel();
    _watchSub = null;
    _watchChannel?.sink.close();
    _watchChannel = null;
    _watchedOrderId = null;
    riderLat = null;
    riderLng = null;
  }

  // ---- Internals ----

  CustomerOrder _orderFromApi(Map<String, dynamic> json) {
    final vendor = _vendors?.vendorById(json['vendor_id'] as String? ?? '');
    return CustomerOrder.fromApi(
      json,
      vendorName: vendor?.storeName ?? '',
      vendorLogoUrl: vendor?.logoUrl ?? '',
    );
  }

  @override
  void dispose() {
    stopWatching();
    super.dispose();
  }
}
