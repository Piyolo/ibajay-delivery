import 'package:flutter/foundation.dart';
import '../models/food_item.dart';
import '../services/mock_data_service.dart';

class MenuProvider extends ChangeNotifier {
  final List<FoodItem> _items = MockDataService.buildMenu();
  int _idCounter = 100;

  List<FoodItem> get items => List.unmodifiable(_items);

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

  void addItem(FoodItem item) {
    _items.add(item);
    notifyListeners();
  }

  String nextId() => 'f${_idCounter++}';

  void updateItem(FoodItem updated) {
    final index = _items.indexWhere((f) => f.id == updated.id);
    if (index != -1) {
      _items[index] = updated;
      notifyListeners();
    }
  }

  void deleteItem(String id) {
    _items.removeWhere((f) => f.id == id);
    notifyListeners();
  }

  void toggleAvailability(String id, bool available) {
    final item = findById(id);
    if (item == null) return;
    item.isAvailable = available;
    notifyListeners();
  }
}
