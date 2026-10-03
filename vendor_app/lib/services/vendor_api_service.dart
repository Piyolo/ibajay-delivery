import 'dart:io';

import 'api_client.dart';

/// Vendor portal API: store profile/status, delivery settings, operating
/// hours, categories, menu CRUD, promotions, order inbox, analytics, and
/// public store reviews.
class VendorApiService {
  VendorApiService(this._client);

  final ApiClient _client;

  // ---- Store ----

  /// Creates the store for a freshly-registered vendor (POST /vendor/me).
  Future<Map<String, dynamic>> createStore(Map<String, dynamic> body) async {
    try {
      return await _client.post('/vendor/me', body: body) as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  Future<Map<String, dynamic>> getStore() async {
    try {
      return await _client.get('/vendor/me') as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  Future<Map<String, dynamic>> updateStore(Map<String, dynamic> body) async {
    try {
      return await _client.put('/vendor/me', body: body) as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  Future<Map<String, dynamic>> updateStatus({
    bool? isOpen,
    bool? isPaused,
  }) async {
    try {
      return await _client.patch('/vendor/me/status', body: {
        if (isOpen != null) 'is_open': isOpen,
        if (isPaused != null) 'is_paused': isPaused,
      }) as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  Future<Map<String, dynamic>> updateDeliverySettings(Map<String, dynamic> body) async {
    try {
      return await _client.put('/vendor/me/delivery-settings', body: body)
          as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  Future<Map<String, dynamic>> updateHours(List<Map<String, dynamic>> hours) async {
    try {
      return await _client.put('/vendor/me/hours', body: {'hours': hours})
          as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  Future<Map<String, dynamic>> updateCategories(List<String> categories) async {
    try {
      return await _client.put('/vendor/me/categories', body: {'categories': categories})
          as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  // ---- Uploads ----

  /// Uploads an image; returns its public URL.
  ///
  /// The content type is derived from the extension explicitly: pickers on
  /// some devices return extension-less cache paths, which would otherwise
  /// upload without a Content-Type at all.
  Future<String> uploadImage(String filePath) async {
    final ext = filePath.contains('.') ? filePath.split('.').last.toLowerCase() : '';
    const mimeByExt = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
    };
    final contentType = mimeByExt[ext] ?? 'image/jpeg';
    final name = filePath.split(Platform.pathSeparator).last;
    try {
      final result = await _client.postMultipart(
        '/uploads',
        filePath: filePath,
        fileName: name,
        contentType: contentType,
      ) as Map<String, dynamic>;
      return result['url'] as String;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  // ---- Menu ----

  Future<List<dynamic>> getMenu() async {
    try {
      return await _client.get('/vendor/me/menu') as List<dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  Future<Map<String, dynamic>> createMenuItem(Map<String, dynamic> body) async {
    try {
      return await _client.post('/vendor/me/menu', body: body) as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  Future<Map<String, dynamic>> updateMenuItem(String id, Map<String, dynamic> body) async {
    try {
      return await _client.patch('/vendor/me/menu/$id', body: body) as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  Future<void> deleteMenuItem(String id) async {
    try {
      await _client.delete('/vendor/me/menu/$id');
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  // ---- Orders ----

  Future<List<dynamic>> getInbox() async {
    try {
      return await _client.get('/orders/vendor/inbox') as List<dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) async {
    try {
      return await _client.patch('/orders/$orderId/status', body: {'status': status})
          as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  Future<Map<String, dynamic>> cancelOrder(String orderId, String reason) async {
    try {
      return await _client
              .post('/orders/$orderId/cancel?reason=${Uri.encodeComponent(reason)}')
          as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  // ---- Delivery tracking ----

  /// POST /tracking/{id}/start — flips the order to out_for_delivery and
  /// opens the customer's live-tracking channel.
  Future<void> startDelivery(String orderId) async {
    try {
      await _client.post('/tracking/$orderId/start');
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  /// POST /tracking/{id}/gps-ping — called every few seconds while out for
  /// delivery; fans out to the customer's WebSocket.
  Future<void> sendGpsPing(String orderId,
      {required double latitude, required double longitude}) async {
    try {
      await _client.post('/tracking/$orderId/gps-ping',
          body: {'latitude': latitude, 'longitude': longitude});
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  // ---- Promotions ----

  Future<List<dynamic>> getPromotions() async {
    try {
      return await _client.get('/vendor/me/promotions') as List<dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  Future<Map<String, dynamic>> createPromotion(Map<String, dynamic> body) async {
    try {
      return await _client.post('/vendor/me/promotions', body: body) as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  Future<Map<String, dynamic>> updatePromotion(String id, Map<String, dynamic> body) async {
    try {
      return await _client.patch('/vendor/me/promotions/$id', body: body)
          as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  Future<void> deletePromotion(String id) async {
    try {
      await _client.delete('/vendor/me/promotions/$id');
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  // ---- Reviews (public store reviews) ----

  Future<List<dynamic>> getStoreReviews(String vendorId) async {
    try {
      return await _client.get('/vendors/$vendorId/reviews') as List<dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }

  // ---- Analytics ----

  Future<Map<String, dynamic>> getAnalytics() async {
    try {
      return await _client.get('/vendor/me/analytics') as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw StoreApiException(e.message, statusCode: e.statusCode);
    }
  }
}

class StoreApiException implements Exception {
  StoreApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}
