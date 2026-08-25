import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../services/mock_data_service.dart';

class OrderProvider extends ChangeNotifier {
  final List<VendorOrder> _orders = MockDataService.buildOrders();

  List<VendorOrder> get all => List.unmodifiable(_orders);

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

  void acceptOrder(String id) => _setStatus(id, OrderStatus.accepted);

  void rejectOrder(String id) => _setStatus(id, OrderStatus.cancelled);

  void advanceStatus(String id) {
    final order = findById(id);
    if (order == null) return;
    final next = order.status.next;
    if (next != null) _setStatus(id, next);
  }

  void _setStatus(String id, OrderStatus status) {
    final order = findById(id);
    if (order == null) return;
    order.status = status;
    notifyListeners();
  }
}