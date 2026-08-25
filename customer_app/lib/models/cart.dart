import 'vendor.dart';

class SelectedOption {
  final String groupName;
  final List<FoodOptionChoiceRef> choices;
  SelectedOption({required this.groupName, required this.choices});

  double get extraTotal => choices.fold(0, (sum, c) => sum + c.extraPrice);
}

class CartItem {
  final String id; // unique per cart line (same food + different options = different line)
  final FoodItemRef foodItem;
  int quantity;
  List<SelectedOption> selectedOptions;
  String specialInstructions;

  CartItem({
    required this.id,
    required this.foodItem,
    this.quantity = 1,
    List<SelectedOption>? selectedOptions,
    this.specialInstructions = '',
  }) : selectedOptions = selectedOptions ?? [];

  double get unitPrice =>
      foodItem.price + selectedOptions.fold(0.0, (sum, o) => sum + o.extraTotal);

  double get lineTotal => unitPrice * quantity;
}

class Cart {
  String? vendorId;
  String? vendorName;
  final List<CartItem> items = [];

  double get subtotal => items.fold(0, (sum, i) => sum + i.lineTotal);
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  bool get isEmpty => items.isEmpty;

  void clear() {
    items.clear();
    vendorId = null;
    vendorName = null;
  }
}
