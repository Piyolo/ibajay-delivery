class OperatingHours {
  final String day;
  bool isOpen;
  String openTime;
  String closeTime;

  OperatingHours({
    required this.day,
    this.isOpen = true,
    this.openTime = '08:00',
    this.closeTime = '20:00',
  });
}

class DeliverySettings {
  bool deliveryEnabled;
  bool pickupEnabled;
  bool scheduledDeliveryEnabled;

  /// Barangays (of Ibajay) this vendor delivers to. Delivery availability
  /// is matched against the customer's address barangay.
  List<String> deliveryBarangays;

  /// Legacy fallback used only when a vendor has no barangay list yet.
  double deliveryRadiusKm;
  double baseDeliveryFee;
  double perKmFee;
  int estimatedPrepMinutes;

  DeliverySettings({
    this.deliveryEnabled = true,
    this.pickupEnabled = true,
    this.scheduledDeliveryEnabled = false,
    List<String>? deliveryBarangays,
    this.deliveryRadiusKm = 5,
    this.baseDeliveryFee = 30,
    this.perKmFee = 8,
    this.estimatedPrepMinutes = 20,
  }) : deliveryBarangays = deliveryBarangays ?? [];

  bool get hasDeliveryAreas => deliveryBarangays.isNotEmpty;

  bool deliversToBarangay(String barangay) =>
      deliveryBarangays.contains(barangay);

  factory DeliverySettings.fromJson(Map<String, dynamic> json) {
    return DeliverySettings(
      deliveryEnabled: json['deliveryEnabled'] as bool? ?? true,
      pickupEnabled: json['pickupEnabled'] as bool? ?? true,
      scheduledDeliveryEnabled: json['scheduledDeliveryEnabled'] as bool? ?? false,
      deliveryBarangays:
          (json['deliveryBarangays'] as List?)?.cast<String>().toList() ?? const [],
      deliveryRadiusKm: (json['deliveryRadiusKm'] as num?)?.toDouble() ?? 5,
      baseDeliveryFee: (json['baseDeliveryFee'] as num?)?.toDouble() ?? 30,
      perKmFee: (json['perKmFee'] as num?)?.toDouble() ?? 8,
      estimatedPrepMinutes: (json['estimatedPrepMinutes'] as num?)?.toInt() ?? 20,
    );
  }
}

class VendorProfile {
  final String id;
  String storeName;
  String description;
  String address;
  double latitude;
  double longitude;
  String logoUrl;
  String bannerUrl;
  List<String> categories;
  bool isOpen;
  bool isPaused;
  bool isVerified;
  double rating;
  int totalReviews;
  List<OperatingHours> operatingHours;
  DeliverySettings deliverySettings;
  List<FoodItemRef> menu;

  VendorProfile({
    required this.id,
    required this.storeName,
    this.description = '',
    this.address = '',
    this.latitude = 0,
    this.longitude = 0,
    this.logoUrl = '',
    this.bannerUrl = '',
    List<String>? categories,
    this.isOpen = true,
    this.isPaused = false,
    this.isVerified = false,
    this.rating = 0,
    this.totalReviews = 0,
    List<OperatingHours>? operatingHours,
    DeliverySettings? deliverySettings,
    List<FoodItemRef>? menu,
  })  : categories = categories ?? [],
        operatingHours = operatingHours ?? [],
        deliverySettings = deliverySettings ?? DeliverySettings(),
        menu = menu ?? [];

  factory VendorProfile.fromJson(Map<String, dynamic> json) {
    final vendorId = json['id'] as String;
    return VendorProfile(
      id: vendorId,
      storeName: json['storeName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      logoUrl: json['logoUrl'] as String? ?? '',
      bannerUrl: json['bannerUrl'] as String? ?? '',
      categories: (json['categories'] as List?)?.map((e) => e as String).toList() ?? [],
      isOpen: json['isOpen'] as bool? ?? true,
      isVerified: json['isVerified'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
      deliverySettings: json['deliverySettings'] != null
          ? DeliverySettings.fromJson(json['deliverySettings'] as Map<String, dynamic>)
          : DeliverySettings(),
      menu: (json['menu'] as List?)
              ?.map((e) => FoodItemRef.fromJson(e as Map<String, dynamic>, vendorId))
              .toList() ??
          [],
    );
  }
}

class FoodOptionChoiceRef {
  final String label;
  final double extraPrice;
  FoodOptionChoiceRef({required this.label, this.extraPrice = 0});

  factory FoodOptionChoiceRef.fromJson(Map<String, dynamic> json) {
    return FoodOptionChoiceRef(
      label: json['label'] as String? ?? '',
      extraPrice: (json['extraPrice'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FoodOptionGroupRef {
  final String groupName;
  final bool isRequired;
  final bool allowMultiple;
  final List<FoodOptionChoiceRef> choices;
  FoodOptionGroupRef({
    required this.groupName,
    this.isRequired = false,
    this.allowMultiple = true,
    required this.choices,
  });

  factory FoodOptionGroupRef.fromJson(Map<String, dynamic> json) {
    return FoodOptionGroupRef(
      groupName: json['groupName'] as String? ?? '',
      isRequired: json['isRequired'] as bool? ?? false,
      allowMultiple: json['allowMultiple'] as bool? ?? true,
      choices: (json['choices'] as List?)
              ?.map((e) => FoodOptionChoiceRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class FoodItemRef {
  final String id;
  final String vendorId;
  String name;
  String description;
  double price;
  String category;
  String imageUrl;
  bool isAvailable;
  bool isFeatured;
  List<FoodOptionGroupRef> options;

  FoodItemRef({
    required this.id,
    required this.vendorId,
    required this.name,
    this.description = '',
    required this.price,
    this.category = '',
    this.imageUrl = '',
    this.isAvailable = true,
    this.isFeatured = false,
    List<FoodOptionGroupRef>? options,
  }) : options = options ?? [];

  factory FoodItemRef.fromJson(Map<String, dynamic> json, String vendorId) {
    return FoodItemRef(
      id: json['id'] as String,
      vendorId: vendorId,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? '',
      isAvailable: json['isAvailable'] as bool? ?? true,
      isFeatured: json['isFeatured'] as bool? ?? false,
      options: (json['options'] as List?)
              ?.map((e) => FoodOptionGroupRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
