import 'dart:developer' as dev;

import '../constants/location_constants.dart';
import '../models/review.dart';
import '../models/vendor.dart';
import '../services/api_client.dart';
import 'mock_vendor_repository.dart';
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
/// If the backend is unreachable (server off, no network, dev machine
/// asleep), it falls back to [MockVendorRepository] so the app stays
/// browsable offline; a warning is logged.
class ApiVendorRepository implements VendorRepository {
  ApiVendorRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  final MockVendorRepository _fallback = MockVendorRepository();

  @override
  Future<List<VendorProfile>> fetchVendors() async {
    try {
      final cards = await _client.get(
        '/vendors/nearby',
        {
          'lat': '${LocationConstants.townLat}',
          'lng': '${LocationConstants.townLng}',
        },
      ) as List;

      final profiles = await Future.wait(
        cards.map((card) async {
          final id = (card as Map<String, dynamic>)['id'] as String;
          final json = await _client.get('/vendors/$id') as Map<String, dynamic>;
          return _profileFromApi(json);
        }),
      );
      return profiles;
    } catch (error) {
      dev.log('API unreachable, falling back to mock vendor data: $error');
      return _fallback.fetchVendors();
    }
  }

  @override
  Future<List<VendorReview>> fetchReviews(String vendorId) async {
    // No reviews endpoint on the backend yet — the ratings/reviews tables
    // exist, but the router is still pending. Return empty for now.
    return [];
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
      ),
      menu: (json['food_items'] as List?)
              ?.map((e) => _foodFromApi(e as Map<String, dynamic>, vendorId))
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
