import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/vendor.dart';
import '../services/api_client.dart';
import '../services/vendor_api_service.dart';

/// Live order inbox against /orders/vendor/inbox with guarded status
/// transitions on the backend (pending → accepted → preparing → ...).
class OrderProvider extends ChangeNotifier {
  OrderProvider({ApiClient? apiClient}) : _api = VendorApiService(apiClient ?? ApiClient());

  final VendorApiService _api;
  final List<VendorOrder> _orders = [];
  bool _isLoading = false;
  String? lastError;

  /// Orders with an action (accept/reject/status advance) currently in
  /// flight — double-taps are ignored until the call settles.
  final Set<String> _busyOrderIds = {};

  List<VendorOrder> get all => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;

  /// Whether an action for [orderId] is still awaiting the backend.
  bool isBusy(String orderId) => _busyOrderIds.contains(orderId);

  List<VendorOrder> byStatus(List<OrderStatus> statuses) =>
      _orders.where((o) => statuses.contains(o.status)).toList()
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));

  List<VendorOrder> get newOrders => byStatus([OrderStatus.pending]);
  List<VendorOrder> get preparingOrders =>
      byStatus([OrderStatus.accepted, OrderStatus.preparing, OrderStatus.ready]);
  List<VendorOrder> get outForDelivery => byStatus([OrderStatus.outForDelivery]);
  List<VendorOrder> get history =>
      byStatus([OrderStatus.delivered, OrderStatus.completed, OrderStatus.cancelled]);

  /// Today's orders, bucketed by PH calendar day (UTC+8) so the dashboard
  /// matches the backend's analytics for evening orders.
  List<VendorOrder> get todaysOrders =>
      _orders.where((o) => isSamePhDay(o.placedAt)).toList();

  double get todaysRevenue => todaysOrders
      .where((o) => o.status != OrderStatus.cancelled)
      .fold(0.0, (sum, o) => sum + o.grandTotal);

  int get pendingCount => newOrders.length;

  VendorOrder? findById(String id) {
    try {
      return _orders.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Pulls the live inbox. On failure it keeps the local list (last sync)
  /// and records [lastError].
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final rows = await _api.getInbox();
      _orders
        ..clear()
        ..addAll(rows.map((r) => VendorOrder.fromApi(r as Map<String, dynamic>)));
      lastError = null;
    } on StoreApiException catch (e) {
      lastError = e.message;
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Live sales analytics for the dashboard (`GET /vendor/me/analytics`).
  Future<Map<String, dynamic>> fetchAnalytics() async {
    try {
      return await _api.getAnalytics();
    } on StoreApiException catch (e) {
      lastError = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Accepts the order. Returns false when the action was skipped (already
  /// in flight) or failed — [lastError] carries the failure message.
  Future<bool> acceptOrder(String id) => _setStatus(id, OrderStatus.accepted);

  /// POST /tracking/{id}/start: the backend flips the order to
  /// out_for_delivery and broadcasts to the customer's tracking channel.
  /// Rethrows so callers never begin GPS streaming for a delivery the
  /// backend did not actually start.
  Future<void> startDelivery(String id) async {
    await _api.startDelivery(id);
    _applyLocal(id, OrderStatus.outForDelivery);
  }

  /// Streams the device position to the backend every few seconds.
  Future<void> sendGpsPing(String id,
      {required double latitude, required double longitude}) async {
    try {
      await _api.sendGpsPing(id, latitude: latitude, longitude: longitude);
      lastError = null;
    } on StoreApiException catch (e) {
      lastError = e.message;
    }
    notifyListeners();
  }

  /// Rejects (cancels) the order with the vendor's chosen reason. Returns
  /// false when skipped (already in flight) or failed — [lastError] carries
  /// the failure message.
  Future<bool> rejectOrder(String id,
      {String reason = 'Rejected by store'}) async {
    if (!_busyOrderIds.add(id)) return false;
    try {
      await _api.cancelOrder(id, reason);
      _applyLocal(id, OrderStatus.cancelled);
      return true;
    } on StoreApiException catch (e) {
      lastError = e.message;
      notifyListeners();
      return false;
    } finally {
      _busyOrderIds.remove(id);
      notifyListeners();
    }
  }

  /// Moves the order to its next status. Returns false when there is no
  /// next step, the action was skipped (already in flight), or the backend
  /// rejected it — [lastError] carries the failure message.
  Future<bool> advanceStatus(String id) async {
    final order = findById(id);
    if (order == null) return false;
    final next = order.status.nextFor(order.fulfillmentType);
    if (next == null) return false;
    return _setStatus(id, next);
  }

  Future<bool> _setStatus(String id, OrderStatus status) async {
    final order = findById(id);
    if (order == null) return false;
    if (!_busyOrderIds.add(id)) return false;
    final previous = order.status;
    order.status = status;
    notifyListeners();
    try {
      await _api.updateOrderStatus(id, status.key);
      lastError = null;
      return true;
    } on StoreApiException catch (e) {
      order.status = previous;
      lastError = e.message;
      notifyListeners();
      return false;
    } finally {
      _busyOrderIds.remove(id);
      notifyListeners();
    }
  }

  void _applyLocal(String id, OrderStatus status) {
    final order = findById(id);
    if (order == null) return;
    order.status = status;
    lastError = null;
    notifyListeners();
  }
}
