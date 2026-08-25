import '../models/vendor.dart';
import '../models/review.dart';

/// Static demo data so the UI is fully explorable before the FastAPI backend
/// is wired in. Swap each method's body for a real API call later — the
/// shapes returned already match what `/api/v1/vendors` etc. will send back.
class MockDataService {
  MockDataService._();
  static final MockDataService instance = MockDataService._();

  // Ibajay, Aklan town center, used as the reference point for demo vendors.
  static const double townLat = 11.5459;
  static const double townLng = 122.2039;

  List<VendorProfile> _vendors = [];

  List<VendorProfile> get vendors {
    if (_vendors.isEmpty) _vendors = _buildVendors();
    return _vendors;
  }

  VendorProfile? vendorById(String id) {
    try {
      return vendors.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  List<String> get allCategories =>
      vendors.expand((v) => v.categories).toSet().toList()..sort();

  List<VendorReview> reviewsFor(String vendorId) => _mockReviews;

  List<VendorProfile> _buildVendors() {
    return [
      VendorProfile(
        id: 'v1',
        storeName: "Aling Nena's Carinderia",
        description: 'Home-style Filipino meals — adobo, sinigang, and daily ulam specials.',
        address: 'Rizal St, Poblacion, Ibajay, Aklan',
        latitude: townLat + 0.004,
        longitude: townLng + 0.003,
        logoUrl: '',
        bannerUrl: '',
        categories: ['Meals', 'Fast Food'],
        isOpen: true,
        isVerified: true,
        rating: 4.7,
        totalReviews: 128,
        deliverySettings: DeliverySettings(
          deliveryEnabled: true,
          pickupEnabled: true,
          scheduledDeliveryEnabled: true,
          deliveryRadiusKm: 5,
          baseDeliveryFee: 25,
          perKmFee: 8,
          estimatedPrepMinutes: 20,
        ),
        menu: [
          FoodItemRef(
            id: 'f1',
            vendorId: 'v1',
            name: 'Chicken Adobo Rice Meal',
            description: 'Classic soy-vinegar braised chicken with garlic rice.',
            price: 95,
            category: 'Meals',
            options: [
              FoodOptionGroupRef(groupName: 'Extras', allowMultiple: true, choices: [
                FoodOptionChoiceRef(label: 'Extra Rice', extraPrice: 15),
                FoodOptionChoiceRef(label: 'Extra Sauce', extraPrice: 10),
              ]),
            ],
          ),
          FoodItemRef(
            id: 'f2',
            vendorId: 'v1',
            name: 'Sinigang na Baboy (Bowl)',
            description: 'Tamarind pork soup with vegetables.',
            price: 110,
            category: 'Meals',
          ),
          FoodItemRef(
            id: 'f3',
            vendorId: 'v1',
            name: 'Halo-Halo',
            description: 'Shaved ice dessert with mixed sweets and ube.',
            price: 65,
            category: 'Desserts',
          ),
        ],
      ),
      VendorProfile(
        id: 'v2',
        storeName: 'Ibajay Burger Bites',
        description: 'Juicy burgers, crispy fries, and shakes made fresh to order.',
        address: 'National Highway, Ibajay, Aklan',
        latitude: townLat - 0.006,
        longitude: townLng + 0.007,
        categories: ['Fast Food', 'Drinks'],
        isOpen: true,
        isVerified: false,
        rating: 4.4,
        totalReviews: 64,
        deliverySettings: DeliverySettings(
          deliveryEnabled: true,
          pickupEnabled: true,
          scheduledDeliveryEnabled: false,
          deliveryRadiusKm: 3,
          baseDeliveryFee: 30,
          perKmFee: 10,
          estimatedPrepMinutes: 15,
        ),
        menu: [
          FoodItemRef(
            id: 'f4',
            vendorId: 'v2',
            name: 'Classic Cheeseburger',
            description: 'Beef patty, cheddar, lettuce, tomato, house sauce.',
            price: 85,
            category: 'Fast Food',
            options: [
              FoodOptionGroupRef(groupName: 'Add-ons', allowMultiple: true, choices: [
                FoodOptionChoiceRef(label: 'Add Cheese', extraPrice: 20),
                FoodOptionChoiceRef(label: 'Add Bacon', extraPrice: 30),
              ]),
            ],
          ),
          FoodItemRef(
            id: 'f5',
            vendorId: 'v2',
            name: 'Crispy Fries (Large)',
            price: 55,
            category: 'Fast Food',
          ),
          FoodItemRef(
            id: 'f6',
            vendorId: 'v2',
            name: 'Iced Choco Shake',
            price: 60,
            category: 'Drinks',
          ),
        ],
      ),
      VendorProfile(
        id: 'v3',
        storeName: 'Sweet Treats Bakeshop',
        description: 'Fresh-baked pandesal, ensaymada, cakes, and pastries daily.',
        address: 'Market Area, Ibajay, Aklan',
        latitude: townLat + 0.009,
        longitude: townLng - 0.004,
        categories: ['Bakery', 'Desserts'],
        isOpen: false,
        isVerified: true,
        rating: 4.9,
        totalReviews: 210,
        deliverySettings: DeliverySettings(
          deliveryEnabled: false,
          pickupEnabled: true,
          scheduledDeliveryEnabled: true,
          deliveryRadiusKm: 2,
          baseDeliveryFee: 0,
          perKmFee: 0,
          estimatedPrepMinutes: 10,
        ),
        menu: [
          FoodItemRef(
            id: 'f7',
            vendorId: 'v3',
            name: 'Ensaymada (Box of 6)',
            price: 150,
            category: 'Bakery',
          ),
          FoodItemRef(
            id: 'f8',
            vendorId: 'v3',
            name: 'Choco Butter Cake Slice',
            price: 75,
            category: 'Desserts',
          ),
        ],
      ),
      VendorProfile(
        id: 'v4',
        storeName: 'Barangay Grill House',
        description: 'Charcoal-grilled pork BBQ, isaw, and pulutan favorites.',
        address: 'Barangay Naubay, Ibajay, Aklan',
        latitude: townLat - 0.011,
        longitude: townLng - 0.008,
        categories: ['Fast Food', 'Meals'],
        isOpen: true,
        isVerified: false,
        rating: 4.5,
        totalReviews: 41,
        deliverySettings: DeliverySettings(
          deliveryEnabled: true,
          pickupEnabled: false,
          scheduledDeliveryEnabled: false,
          deliveryRadiusKm: 4,
          baseDeliveryFee: 20,
          perKmFee: 8,
          estimatedPrepMinutes: 25,
        ),
        menu: [
          FoodItemRef(
            id: 'f9',
            vendorId: 'v4',
            name: 'Pork BBQ (3 Sticks)',
            price: 60,
            category: 'Meals',
          ),
          FoodItemRef(
            id: 'f10',
            vendorId: 'v4',
            name: 'Grilled Isaw (5 Sticks)',
            price: 40,
            category: 'Meals',
          ),
        ],
      ),
    ];
  }

  final List<VendorReview> _mockReviews = [
    VendorReview(
      id: 'r1',
      customerName: 'Maria S.',
      stars: 5,
      comment: 'Sobrang sarap and the adobo tastes just like home. Fast delivery too!',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      vendorResponse: 'Thank you so much, Maria! See you again soon.',
    ),
    VendorReview(
      id: 'r2',
      customerName: 'Jerome T.',
      stars: 4,
      comment: 'Good portion size, arrived a bit later than the estimate.',
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
    ),
    VendorReview(
      id: 'r3',
      customerName: 'Anna L.',
      stars: 5,
      comment: 'Best halo-halo in town!',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
  ];
}
