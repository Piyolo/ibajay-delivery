import 'api_client.dart';

/// Vendor portal API: store profile/status, delivery settings, operating
/// hours, categories, menu CRUD, order inbox, and analytics.
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
