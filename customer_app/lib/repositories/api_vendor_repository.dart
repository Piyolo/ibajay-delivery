import '../constants/location_constants.dart';
import '../models/review.dart';
import '../models/vendor.dart';
import '../services/api_client.dart';
import 'vendor_repository.dart';

/// Live implementation of [VendorRepository] backed by the FastAPI backend
/// (`/api/v1/vendors/*`), which reads from PostgreSQL.
///
/// The backend's `/vendors/nearby` returns summary cards only, so
/// [fetchVendors] fetches each store's full profile (menu, options,
/// categories) to satisfy the app's client-side filtering, "Featured
/// Foods" and search logic. Ibajay is small — a handful of parallel
/// profile requests is fine.
///
/// All failures are rethrown so the UI shows an honest error state —
/// masking connectivity problems with fabricated stores would misrepresent
/// the platform during beta.
class ApiVendorRepository implements VendorRepository {
  ApiVendorRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<List<VendorProfile>> fetchVendors({double? refLat, double? refLng}) async {
    try {
      final cards = await _client.get(
        '/vendors/nearby',
        {
          'lat': '${refLat ?? LocationConstants.townLat}',
          'lng': '${refLng ?? LocationConstants.townLng}',
        },
      ) as List;

      // A card id must be a UUID for /vendors/{id} to resolve — anything
      // else means the payload shape changed; don't build garbage requests.
      final ids = cards
          .map((card) => (card as Map<String, dynamic>)['id'])
          .whereType<String>()
          .where(_isUuid)
          .toList();

      final profiles = await Future.wait(
        ids.map((id) async {
          final json = await _client.get('/vendors/$id') as Map<String, dynamic>;
          return _profileFromApi(json);
        }),
      );
      return profiles;
    } on ApiException {
      // Transport or HTTP failure alike: surface it. Never substitute
      // fabricated stores for the real (possibly empty) marketplace.
      rethrow;
    }
  }

  static bool _isUuid(String value) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value);

  @override
  Future<List<VendorReview>> fetchReviews(String vendorId) async {
    try {
      final rows = await _client.get('/vendors/$vendorId/reviews', {'limit': '50'}) as List;
      return rows
          .map((e) => VendorReview.fromApi(e as Map<String, dynamic>))
          .toList();
    } on ApiException catch (error) {
      if (error.statusCode != null && error.statusCode != 404) rethrow;
      // No reviews yet (or offline) — an empty list is the honest state.
      return [];
    }
  }

  // --- snake_case API -> camelCase app models ---

  VendorProfile _profileFromApi(Map<String, dynamic> json) {
    final vendorId = json['id'] as String;
    return VendorProfile(
      id: vendorId,
      storeName: json['store_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      logoUrl: json['logo_url'] as String? ?? '',
      bannerUrl: json['banner_url'] as String? ?? '',
      categories: (json['categories'] as List?)?.cast<String>().toList() ?? [],
      isOpen: json['is_open'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      rating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalReviews: (json['total_reviews'] as num?)?.toInt() ?? 0,
      deliverySettings: DeliverySettings(
        deliveryEnabled: json['delivery_enabled'] as bool? ?? true,
        pickupEnabled: json['pickup_enabled'] as bool? ?? true,
        scheduledDeliveryEnabled: json['scheduled_delivery_enabled'] as bool? ?? false,
        deliveryRadiusKm: (json['delivery_radius_km'] as num?)?.toDouble() ?? 5,
        baseDeliveryFee: (json['base_delivery_fee'] as num?)?.toDouble() ?? 30,
        perKmFee: (json['fee_per_km'] as num?)?.toDouble() ?? 8,
        estimatedPrepMinutes: (json['estimated_prep_minutes'] as num?)?.toInt() ?? 20,
        deliveryBarangays:
            (json['delivery_barangays'] as List?)?.cast<String>().toList() ?? const [],
      ),
      menu: (json['food_items'] as List?)
              ?.map((e) => _foodFromApi(e as Map<String, dynamic>, vendorId))
              .toList() ??
          [],
      promotions: (json['promotions'] as List?)
              ?.map((e) => StorePromo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  FoodItemRef _foodFromApi(Map<String, dynamic> json, String vendorId) {
    final images = (json['images'] as List?)?.cast<String>().toList() ?? const [];
    return FoodItemRef(
      id: json['id'] as String,
      vendorId: vendorId,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? '',
      imageUrl: images.isNotEmpty ? images.first : '',
      isAvailable: json['is_available'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      options: (json['options'] as List?)
              ?.map((e) => _optionGroupFromApi(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  FoodOptionGroupRef _optionGroupFromApi(Map<String, dynamic> json) {
    return FoodOptionGroupRef(
      groupName: json['group_name'] as String? ?? '',
      isRequired: json['is_required'] as bool? ?? false,
      allowMultiple: json['allow_multiple'] as bool? ?? true,
      choices: (json['choices'] as List?)
              ?.map((e) {
                final c = e as Map<String, dynamic>;
                return FoodOptionChoiceRef(
                  label: c['label'] as String? ?? '',
                  extraPrice: (c['extra_price'] as num?)?.toDouble() ?? 0,
                );
              })
              .toList() ??
          [],
    );
  }
}
