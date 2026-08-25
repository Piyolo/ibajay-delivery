import 'api_client.dart';

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Typed failure for auth errors; the UI surfaces [message] directly.
class AuthException implements Exception {
  AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Auth client for the vendor app. Login is by mobile number + password
/// (the same credential the store owner uses); the account must carry the
/// `vendor` role to manage a store.
class AuthApiService {
  AuthApiService(this._client);

  final ApiClient _client;

  Future<AuthTokens> login({
    required String mobileNumber,
    required String password,
  }) async {
    return _tokened(() => _client.post('/auth/login', body: {
          'mobile_number': mobileNumber,
          'password': password,
        }));
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    return _tokened(
      () => _client.post('/auth/refresh', body: {'refresh_token': refreshToken}),
    );
  }

  /// GET /auth/me — used to verify the account is a vendor before entering
  /// the portal.
  Future<Map<String, dynamic>> me() async {
    try {
      return await _client.get('/auth/me') as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw AuthException(e.message, statusCode: e.statusCode);
    }
  }

  /// Verifies the current password by attempting a real login. Returns the
  /// backend's error message on failure, null on success.
  Future<String?> checkCurrentPassword({
    required String mobileNumber,
    required String currentPassword,
  }) async {
    try {
      await login(mobileNumber: mobileNumber, password: currentPassword);
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _client.post('/auth/change-password', body: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': newPassword,
      });
    } on ApiException catch (e) {
      throw AuthException(e.message, statusCode: e.statusCode);
    }
  }

  Future<AuthTokens> _tokened(Future<dynamic> Function() call) async {
    try {
      final json = await call() as Map<String, dynamic>;
      return AuthTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
      );
    } on ApiException catch (e) {
      throw AuthException(e.message, statusCode: e.statusCode);
    }
  }
}
