import 'package:flutter/foundation.dart';
import '../models/order.dart';
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

  List<VendorOrder> get all => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;

  List<VendorOrder> byStatus(List<OrderStatus> statuses) =>
      _orders.where((o) => statuses.contains(o.status)).toList()
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));

  List<VendorOrder> get newOrders => byStatus([OrderStatus.pending]);
  List<VendorOrder> get preparingOrders =>
      byStatus([OrderStatus.accepted, OrderStatus.preparing, OrderStatus.ready]);
  List<VendorOrder> get outForDelivery => byStatus([OrderStatus.outForDelivery]);
  List<VendorOrder> get history =>
      byStatus([OrderStatus.delivered, OrderStatus.completed, OrderStatus.cancelled]);

  List<VendorOrder> get todaysOrders {
    final now = DateTime.now();
    return _orders.where((o) =>
        o.placedAt.year == now.year && o.placedAt.month == now.month && o.placedAt.day == now.day).toList();
  }

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

  /// Pulls the live inbox. Falls back to the local list (mock seed / last
  /// sync) when unreachable.
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

  Future<void> acceptOrder(String id) => _setStatus(id, OrderStatus.accepted);

  Future<void> rejectOrder(String id) =>
      _api.cancelOrder(id, 'Rejected by store').then((_) => _applyLocal(id, OrderStatus.cancelled))
          .catchError((Object e) {
        lastError = e is StoreApiException ? e.message : e.toString();
        notifyListeners();
      });

  Future<void> advanceStatus(String id) async {
    final order = findById(id);
    if (order == null) return;
    final next = order.status.next;
    if (next != null) await _setStatus(id, next);
  }

  Future<void> _setStatus(String id, OrderStatus status) async {
    final order = findById(id);
    if (order == null) return;
    final previous = order.status;
    order.status = status;
    notifyListeners();
    try {
      await _api.updateOrderStatus(id, status.key);
      lastError = null;
    } on StoreApiException catch (e) {
      order.status = previous;
      lastError = e.message;
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
