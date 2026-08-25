import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ibajay_eats/repositories/api_vendor_repository.dart';
import 'package:ibajay_eats/services/api_client.dart';

/// Serves the exact JSON shapes captured from the live API
/// (`/api/v1/vendors/nearby` + `/api/v1/vendors/{id}`) so the
/// snake_case -> camelCase mapping is tested deterministically,
/// without needing the backend running.
class _FakeApiServer extends http.BaseClient {
  static const vendorId = '027a45d1-63c5-4a4b-b335-4a6ff0d2343a';

  static const nearbyBody = '''
[{"id":"$vendorId","store_name":"Aling Nena's Carinderia","logo_url":null,"average_rating":4.7,"is_open":true,"delivery_enabled":true,"pickup_enabled":true,"estimated_prep_minutes":20,"distance_km":0.0}]
''';

  static const profileBody = '''
{"id":"$vendorId","store_name":"Aling Nena's Carinderia","description":"Home-style Filipino meals","logo_url":null,"banner_url":null,"address":"Rizal St, Poblacion, Ibajay, Aklan","latitude":11.5499,"longitude":122.2069,"average_rating":4.7,"total_reviews":128,"is_open":true,"is_verified":true,"delivery_enabled":true,"pickup_enabled":true,"scheduled_delivery_enabled":true,"delivery_radius_km":5.0,"base_delivery_fee":25.0,"fee_per_km":8.0,"estimated_prep_minutes":20,"categories":["Meals","Fast Food"],"food_items":[{"id":"a1d1f969-9bec-4f10-8b72-7851af57110b","name":"Chicken Adobo Rice Meal","description":"Classic soy-vinegar braised chicken with garlic rice.","price":95.0,"is_available":true,"is_featured":true,"category":"Meals","images":[],"options":[{"id":"e21da68a-97f7-4d9c-b0ea-70524b4e1d20","group_name":"Extras","is_required":false,"allow_multiple":true,"choices":[{"id":"df0bff4d-1b1b-4c79-858c-e27ed1ceffe4","label":"Extra Rice","extra_price":15.0},{"id":"4bb215ed-8dc3-4f33-9dc0-f4cb4fb93d2b","label":"Extra Sauce","extra_price":10.0}]}]},{"id":"7804cc95-eb37-47e6-8e4d-4c657e4a518d","name":"Sinigang na Baboy (Bowl)","description":"Tamarind pork soup with vegetables.","price":110.0,"is_available":true,"is_featured":true,"category":"Meals","images":[],"options":[]},{"id":"9b81dc06-12db-4260-9c25-21628ab7b985","name":"Halo-Halo","description":"Shaved ice dessert with mixed sweets and ube.","price":65.0,"is_available":true,"is_featured":false,"category":"Desserts","images":[],"options":[]}]}
''';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final String body;
    if (path.endsWith('/vendors/nearby')) {
      body = nearbyBody;
    } else if (path.contains('/vendors/')) {
      body = profileBody;
    } else {
      body = '{}';
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

void main() {
  test('maps live API JSON onto the app models', () async {
    final repository = ApiVendorRepository(
      client: ApiClient(client: _FakeApiServer()),
    );

    final vendors = await repository.fetchVendors();

    expect(vendors, hasLength(1));
    final vendor = vendors.single;

    expect(vendor.id, _FakeApiServer.vendorId);
    expect(vendor.storeName, "Aling Nena's Carinderia");
    expect(vendor.address, 'Rizal St, Poblacion, Ibajay, Aklan');
    expect(vendor.latitude, 11.5499);
    expect(vendor.longitude, 122.2069);
    expect(vendor.rating, 4.7);
    expect(vendor.totalReviews, 128);
    expect(vendor.isOpen, isTrue);
    expect(vendor.isVerified, isTrue);
    expect(vendor.categories, ['Meals', 'Fast Food']);

    final settings = vendor.deliverySettings;
    expect(settings.deliveryEnabled, isTrue);
    expect(settings.scheduledDeliveryEnabled, isTrue);
    expect(settings.deliveryRadiusKm, 5.0);
    expect(settings.baseDeliveryFee, 25.0);
    expect(settings.perKmFee, 8.0);
    expect(settings.estimatedPrepMinutes, 20);

    expect(vendor.menu, hasLength(3));
    final adobo = vendor.menu.first;
    expect(adobo.id, 'a1d1f969-9bec-4f10-8b72-7851af57110b');
    expect(adobo.name, 'Chicken Adobo Rice Meal');
    expect(adobo.price, 95.0);
    expect(adobo.category, 'Meals');
    expect(adobo.isFeatured, isTrue);
    expect(adobo.isAvailable, isTrue);

    final extras = adobo.options.single;
    expect(extras.groupName, 'Extras');
    expect(extras.allowMultiple, isTrue);
    expect(extras.choices.map((c) => c.label), ['Extra Rice', 'Extra Sauce']);
    expect(extras.choices.first.extraPrice, 15.0);

    // Drives the Home screen's "Featured Foods" carousel.
    final featured = vendor.menu.where((f) => f.isFeatured);
    expect(featured, hasLength(2));
  });
}
