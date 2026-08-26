import 'package:flutter/foundation.dart';
import '../models/promotion.dart';
import '../services/api_client.dart';
import '../services/vendor_api_service.dart';

/// Store promotions against /vendor/me/promotions. Local state updates
/// optimistically and syncs to the backend; [load] pulls the truth.
class PromotionsProvider extends ChangeNotifier {
  PromotionsProvider({ApiClient? apiClient})
      : _api = VendorApiService(apiClient ?? ApiClient());

  final VendorApiService _api;
  final List<StorePromotion> _promotions = [];
  bool _isLoading = false;
  String? lastError;

  List<StorePromotion> get promotions => List.unmodifiable(_promotions);
  bool get isLoading => _isLoading;

  /// Promotions currently visible to customers (active + within dates).
  List<StorePromotion> get live => _promotions.where((p) {
        if (!p.isActive) return false;
        final now = DateTime.now();
        if (p.startsAt != null && now.isBefore(p.startsAt!)) return false;
        if (p.endsAt != null && now.isAfter(p.endsAt!)) return false;
        return true;
      }).toList();

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final rows = await _api.getPromotions();
      _promotions
        ..clear()
        ..addAll(rows.map((r) => StorePromotion.fromApi(r as Map<String, dynamic>)));
      lastError = null;
    } on StoreApiException catch (e) {
      lastError = e.message;
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Returns true when the promotion was actually created.
  Future<bool> create(StorePromotion promo) async {
    try {
      final created = await _api.createPromotion(promo.toCreateApi());
      _promotions.insert(0, StorePromotion.fromApi(created));
      lastError = null;
      notifyListeners();
      return true;
    } on StoreApiException catch (e) {
      lastError = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleActive(StorePromotion promo, bool active) async {
    final previous = promo.isActive;
    promo.isActive = active;
    notifyListeners();
    try {
      await _api.updatePromotion(promo.id, {'is_active': active});
      lastError = null;
    } on StoreApiException catch (e) {
      promo.isActive = previous;
      lastError = e.message;
      notifyListeners();
    }
  }

  Future<void> delete(String id) async {
    final index = _promotions.indexWhere((p) => p.id == id);
    if (index == -1) return;
    final removed = _promotions.removeAt(index);
    notifyListeners();
    try {
      await _api.deletePromotion(id);
      lastError = null;
    } on StoreApiException catch (e) {
      _promotions.insert(index, removed);
      lastError = e.message;
      notifyListeners();
    }
  }
}
