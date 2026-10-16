import 'package:flutter_test/flutter_test.dart';

import 'package:ibajay_eats/models/cart.dart';
import 'package:ibajay_eats/models/vendor.dart';

/// Cart persistence round-trip: the JSON snapshot that keeps an
/// order-in-progress alive across process restarts must rebuild identically
/// (same item identity, quantity, options and instructions).
void main() {
  FoodItemRef food() => FoodItemRef(
        id: 'food-1',
        vendorId: 'vendor-1',
        name: 'Chicken Adobo Rice Meal',
        description: 'Classic soy-vinegar braised chicken',
        price: 95,
        category: 'Meals',
        imageUrl: 'http://example.com/a.png',
      );

  CartItem item() => CartItem(
        id: 'ci_42',
        foodItem: food(),
        quantity: 2,
        selectedOptions: [
          SelectedOption(
            groupName: 'Extras',
            choices: [
              FoodOptionChoiceRef(label: 'Extra Rice', extraPrice: 15),
            ],
          ),
        ],
        specialInstructions: 'No onions please',
      );

  test('toPersistedJson writes item snapshots and checkout keys', () {
    final cart = Cart()
      ..vendorId = 'vendor-1'
      ..vendorName = "Aling Nena's Carinderia"
      ..items.add(item());

    final json = cart.toPersistedJson();
    expect(json['vendorId'], 'vendor-1');
    final items = (json['items'] as List).first as Map<String, dynamic>;
    expect(items['itemId'], 'food-1');
    expect(items['quantity'], 2);
    expect(items['specialInstructions'], 'No onions please');
  });

  test('round-trip restores vendor binding and line details', () {
    final cart = Cart()
      ..vendorId = 'vendor-1'
      ..vendorName = "Aling Nena's Carinderia"
      ..items.add(item());

    final restored =
        Cart.fromPersistedJson(cart.toPersistedJson());

    expect(restored.vendorId, 'vendor-1');
    expect(restored.vendorName, "Aling Nena's Carinderia");
    expect(restored.itemCount, 2);
    expect(restored.items.single.foodItem.id, 'food-1');
    expect(restored.items.single.foodItem.price, 95);
    expect(restored.items.single.selectedOptions.single.groupName, 'Extras');
    expect(
      restored.items.single.selectedOptions.single.choices.single.label,
      'Extra Rice',
    );
    expect(
      restored.items.single.selectedOptions.single.choices.single.extraPrice,
      15,
    );
    expect(restored.items.single.specialInstructions, 'No onions please');
    expect(restored.subtotal, closeTo((95 + 15) * 2, 0.001));
  });

  test('empty cart persists as an empty snapshot', () {
    final json = Cart().toPersistedJson();
    expect((json['items'] as List), isEmpty);
    expect(Cart.fromPersistedJson(json).isEmpty, isTrue);
  });

  test('corrupt snapshots are rejected by field defaults, not crashes', () {
    final restored = Cart.fromPersistedJson({
      'items': [
        {'quantity': 'not-a-number'},
      ],
    });
    expect(restored.items.single.quantity, 1); // default
    expect(restored.items.single.foodItem.name, '');
  });
}
