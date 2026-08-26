import 'package:flutter/foundation.dart';
import '../models/food_item.dart';
import '../services/api_client.dart';
import '../services/vendor_api_service.dart';

/// Live menu management against /vendor/me/menu.
///
/// Local state updates optimistically; every mutation is synced to the
/// backend. A [load] refresh pulls the authoritative list (used at login
/// and via pull-to-refresh).
class MenuProvider extends ChangeNotifier {
  MenuProvider({ApiClient? apiClient}) : _api = VendorApiService(apiClient ?? ApiClient());

  final VendorApiService _api;
  final List<FoodItem> _items = [];
  bool _isLoading = false;
  String? lastError;

  List<FoodItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;

  List<FoodItem> byCategory(String category) =>
      _items.where((f) => f.category == category).toList();

  Set<String> get categoriesInUse => _items.map((f) => f.category).toSet();

  FoodItem? findById(String id) {
    try {
      return _items.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Pulls the live menu from the backend. Falls back to the local list
  /// (kept from mock seed / last sync) when unreachable.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final rows = await _api.getMenu();
      _items
        ..clear()
        ..addAll(rows.map((r) => FoodItem.fromApi(r as Map<String, dynamic>)));
      lastError = null;
    } on StoreApiException catch (e) {
      lastError = e.message;
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Adds [item] (with a temporary local id) and swaps in the server's
  /// copy once created.
  Future<void> addItem(FoodItem item) async {
    _items.add(item);
    notifyListeners();
    try {
      final created = await _api.createMenuItem(item.toApi());
      final serverItem = FoodItem.fromApi(created);
      final index = _items.indexWhere((f) => f.id == item.id);
      if (index != -1) _items[index] = serverItem;
      lastError = null;
    } on StoreApiException catch (e) {
      lastError = e.message;
    }
    notifyListeners();
  }

  Future<void> updateItem(FoodItem updated) async {
    final index = _items.indexWhere((f) => f.id == updated.id);
    if (index == -1) return;
    final previous = _items[index];
    _items[index] = updated;
    notifyListeners();
    try {
      final saved = await _api.updateMenuItem(updated.id, updated.toApi());
      _items[index] = FoodItem.fromApi(saved);
      lastError = null;
    } on StoreApiException catch (e) {
      _items[index] = previous;
      lastError = e.message;
    }
    notifyListeners();
  }

  /// Uploads an image and returns its public URL (POST /uploads).
  Future<String> uploadImage(String filePath) => _api.uploadImage(filePath);

  Future<void> deleteItem(String id) async {
    final index = _items.indexWhere((f) => f.id == id);
    if (index == -1) return;
    final removed = _items.removeAt(index);
    notifyListeners();
    try {
      await _api.deleteMenuItem(id);
      lastError = null;
    } on StoreApiException catch (e) {
      _items.insert(index, removed);
      lastError = e.message;
      notifyListeners();
    }
  }

  Future<void> toggleAvailability(String id, bool available) async {
    final item = findById(id);
    if (item == null) return;
    final previous = item.isAvailable;
    item.isAvailable = available;
    notifyListeners();
    try {
      await _api.updateMenuItem(id, {'is_available': available});
      lastError = null;
    } on StoreApiException catch (e) {
      item.isAvailable = previous;
      lastError = e.message;
      notifyListeners();
    }
  }
}
