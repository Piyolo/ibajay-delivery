class FoodAddon {
  String name;
  double price;
  FoodAddon({required this.name, required this.price});
}

class FoodItem {
  final String id;
  String name;
  String description;
  double price;
  String category;
  String imageUrl;
  bool isAvailable;
  List<FoodAddon> addons;
  int totalSold;

  FoodItem({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    required this.category,
    this.imageUrl = '',
    this.isAvailable = true,
    List<FoodAddon>? addons,
    this.totalSold = 0,
  }) : addons = addons ?? [];
}
