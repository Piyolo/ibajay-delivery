import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/cart.dart';
import '../models/vendor.dart';
import '../services/preferences_service.dart';

/// The one-cart / one-vendor state. Persisted per signed-in user so a
/// process kill (or app update) no longer silently wipes an order-in-progress:
/// every mutation writes a JSON snapshot under the user's prefs namespace
/// (same attach/detach lifecycle as LocationProvider/FavoritesProvider).
class CartProvider extends ChangeNotifier {
  static const _kCartForPrefix = 'cart.';

  final Cart _cart = Cart();
  String? _uid;
  Cart get cart => _cart;

  /// Per-user key: cart state follows the signed-in account.
  String _keyFor(String uid) => '$_kCartForPrefix$uid.cart';

  /// Attaches the provider to a signed-in user and restores that user's
  /// persisted cart (once per sign-in; later mutations keep it in sync).
  Future<void> attachUser(String uid) async {
    _uid = uid;
    try {
      final raw = await PreferencesService.getString(_keyFor(uid));
      if (raw == null || raw.isEmpty) return;
      _cart.clear();
      final restored = Cart.fromPersistedJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      _cart.vendorId = restored.vendorId;
      _cart.vendorName = restored.vendorName;
      _cart.items.addAll(restored.items);
      notifyListeners();
    } catch (_) {
      // Corrupt snapshot: start clean rather than block ordering.
      _cart.clear();
      notifyListeners();
    }
  }

  /// Signs-out cleanup: drop the account context and the in-memory cart.
  void detachUser() {
    _uid = null;
    _cart.clear();
    notifyListeners();
  }

  /// Fire-and-forget snapshot write after every mutation.
  Future<void> _persist() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final raw = jsonEncode(_cart.toPersistedJson());
      if (_cart.isEmpty) {
        await PreferencesService.remove(_keyFor(uid));
      } else {
        await PreferencesService.setString(_keyFor(uid), raw);
      }
    } catch (_) {
      // Persistence is best-effort; ordering continues regardless.
    }
  }

  /// Returns an error message if the add would conflict with the current
  /// cart's vendor, otherwise null and performs the add.
  String? addItem({
    required FoodItemRef foodItem,
    required VendorProfile vendor,
    int quantity = 1,
    List<SelectedOption>? options,
    String specialInstructions = '',
  }) {
    if (_cart.vendorId != null && _cart.vendorId != vendor.id) {
      return 'starting_new_cart_confirmation';
    }
    _cart.vendorId = vendor.id;
    _cart.vendorName = vendor.storeName;
    _cart.items.add(CartItem(
      id: 'ci_${DateTime.now().microsecondsSinceEpoch}',
      foodItem: foodItem,
      quantity: quantity,
      selectedOptions: options,
      specialInstructions: specialInstructions,
    ));
    notifyListeners();
    _persist();
    return null;
  }

  void forceStartNewCart({
    required FoodItemRef foodItem,
    required VendorProfile vendor,
    int quantity = 1,
    List<SelectedOption>? options,
    String specialInstructions = '',
  }) {
    _cart.clear();
    addItem(
      foodItem: foodItem,
      vendor: vendor,
      quantity: quantity,
      options: options,
      specialInstructions: specialInstructions,
    );
  }

  void updateQuantity(String cartItemId, int delta) {
    final index = _cart.items.indexWhere((i) => i.id == cartItemId);
    if (index == -1) return;
    final item = _cart.items[index];
    item.quantity += delta;
    if (item.quantity <= 0) {
      _cart.items.removeAt(index);
    }
    if (_cart.items.isEmpty) _cart.clear();
    notifyListeners();
    _persist();
  }

  void removeItem(String cartItemId) {
    _cart.items.removeWhere((i) => i.id == cartItemId);
    if (_cart.items.isEmpty) _cart.clear();
    notifyListeners();
    _persist();
  }

  void clear() {
    _cart.clear();
    notifyListeners();
    _persist();
  }
}
