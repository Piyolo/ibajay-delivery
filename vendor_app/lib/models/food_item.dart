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
  bool isFeatured;
  List<FoodAddon> addons;

  FoodItem({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    required this.category,
    this.imageUrl = '',
    this.isAvailable = true,
    this.isFeatured = false,
    List<FoodAddon>? addons,
  }) : addons = addons ?? [];

  /// Maps the backend's menu-item payload (snake_case, option groups with
  /// choices, list of image URLs) onto the app's flat model: every group's
  /// choices are flattened into [addons], and the first image becomes
  /// [imageUrl].
  factory FoodItem.fromApi(Map<String, dynamic> json) {
    final addons = <FoodAddon>[];
    for (final group in (json['options'] as List?) ?? []) {
      for (final choice in (group as Map<String, dynamic>)['choices'] as List? ?? []) {
        final c = choice as Map<String, dynamic>;
        addons.add(FoodAddon(
          name: c['label'] as String? ?? '',
          price: (c['extra_price'] as num?)?.toDouble() ?? 0,
        ));
      }
    }
    final images = (json['images'] as List?)?.cast<String>().toList() ?? const [];
    return FoodItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? '',
      imageUrl: images.isNotEmpty ? images.first : '',
      isAvailable: json['is_available'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      addons: addons,
    );
  }

  /// Serializes back to the backend's menu-item shape: addons become the
  /// choices of a single "Add-ons" group.
  Map<String, dynamic> toApi() => {
        'name': name,
        'description': description.isEmpty ? null : description,
        'price': price,
        'category': category.isEmpty ? null : category,
        'is_available': isAvailable,
        'is_featured': isFeatured,
        'images': imageUrl.isEmpty ? [] : [imageUrl],
        'options': addons.isEmpty
            ? []
            : [
                {
                  'group_name': 'Add-ons',
                  'is_required': false,
                  'allow_multiple': true,
                  'choices': [
                    for (final a in addons) {'label': a.name, 'extra_price': a.price}
                  ],
                }
              ],
      };
}
