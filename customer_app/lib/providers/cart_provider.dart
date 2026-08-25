import 'package:flutter/material.dart';
import '../models/cart.dart';
import '../models/vendor.dart';

class CartProvider extends ChangeNotifier {
  final Cart _cart = Cart();
  Cart get cart => _cart;

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
    final item = _cart.items.firstWhere((i) => i.id == cartItemId);
    item.quantity += delta;
    if (item.quantity <= 0) {
      _cart.items.removeWhere((i) => i.id == cartItemId);
    }
    if (_cart.items.isEmpty) _cart.clear();
    notifyListeners();
  }

  void removeItem(String cartItemId) {
    _cart.items.removeWhere((i) => i.id == cartItemId);
    if (_cart.items.isEmpty) _cart.clear();
    notifyListeners();
  }

  void clear() {
    _cart.clear();
    notifyListeners();
  }
}
