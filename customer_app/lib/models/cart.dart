import 'vendor.dart';

/// Restore readers for `toPersistedJson` snapshots, which come back from
/// device storage: a value whose runtime type doesn't match (e.g. a String
/// quantity after hand-editing) must degrade to the field's default via the
/// caller's `??` — an ordinary `as num?` cast would crash the cart instead.
num? _persistedNum(Object? value) => value is num ? value : null;
String? _persistedString(Object? value) => value is String ? value : null;
bool? _persistedBool(Object? value) => value is bool ? value : null;
List? _persistedList(Object? value) => value is List ? value : null;
Map<String, dynamic>? _persistedMap(Object? value) =>
    value is Map<String, dynamic> ? value : null;

class SelectedOption {
  final String groupName;
  final List<FoodOptionChoiceRef> choices;
  SelectedOption({required this.groupName, required this.choices});

  double get extraTotal => choices.fold(0, (sum, c) => sum + c.extraPrice);

  Map<String, dynamic> toPersistedJson() => {
        'groupName': groupName,
        'choices': choices
            .map((c) => {'label': c.label, 'extraPrice': c.extraPrice})
            .toList(),
      };

  static SelectedOption fromPersistedJson(Map<String, dynamic> json) {
    return SelectedOption(
      groupName: _persistedString(json['groupName']) ?? '',
      choices: (_persistedList(json['choices']) ?? [])
              .map(_persistedMap)
              .whereType<Map<String, dynamic>>()
              .map((choice) => FoodOptionChoiceRef(
                    label: _persistedString(choice['label']) ?? '',
                    extraPrice:
                        _persistedNum(choice['extraPrice'])?.toDouble() ?? 0,
                  ))
              .toList(),
    );
  }
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

  /// The minimum needed to rebuild the cart after a process restart: item
  /// identity/name/price snapshot, quantity, options, instructions.
  Map<String, dynamic> toPersistedJson() => {
        if (vendorId != null) 'vendorId': vendorId,
        if (vendorName != null) 'vendorName': vendorName,
        'items': items
            .map((i) => {
                  'id': i.id,
                  'itemId': i.foodItem.id,
                  'name': i.foodItem.name,
                  'description': i.foodItem.description,
                  'price': i.foodItem.price,
                  'category': i.foodItem.category,
                  'imageUrl': i.foodItem.imageUrl,
                  'isAvailable': i.foodItem.isAvailable,
                  'isFeatured': i.foodItem.isFeatured,
                  'quantity': i.quantity,
                  'options':
                      i.selectedOptions.map((o) => o.toPersistedJson()).toList(),
                  'specialInstructions': i.specialInstructions,
                })
            .toList(),
      };

  static Cart fromPersistedJson(Map<String, dynamic> json) {
    final cart = Cart();
    cart.vendorId = _persistedString(json['vendorId']);
    cart.vendorName = _persistedString(json['vendorName']);
    final rawItems = _persistedList(json['items']);
    if (rawItems != null) {
      for (final raw in rawItems) {
        final map = _persistedMap(raw);
        if (map == null) continue; // corrupt entry: skip it, don't crash
        final vendorId = cart.vendorId ?? '';
        final quantity = _persistedNum(map['quantity'])?.toInt() ?? 1;
        cart.items.add(CartItem(
          id: _persistedString(map['id']) ?? 'ci_restored',
          foodItem: FoodItemRef(
            id: _persistedString(map['itemId']) ?? '',
            vendorId: vendorId,
            name: _persistedString(map['name']) ?? '',
            description: _persistedString(map['description']) ?? '',
            price: _persistedNum(map['price'])?.toDouble() ?? 0,
            category: _persistedString(map['category']) ?? '',
            imageUrl: _persistedString(map['imageUrl']) ?? '',
            isAvailable: _persistedBool(map['isAvailable']) ?? true,
            isFeatured: _persistedBool(map['isFeatured']) ?? false,
          ),
          quantity: quantity < 1 ? 1 : quantity,
          selectedOptions: (_persistedList(map['options']) ?? [])
              .map(_persistedMap)
              .whereType<Map<String, dynamic>>()
              .map(SelectedOption.fromPersistedJson)
              .toList(),
          specialInstructions: _persistedString(map['specialInstructions']) ?? '',
        ));
      }
    }
    return cart;
  }
}
