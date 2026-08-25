import 'api_client.dart';

/// Access/refresh token pair returned by the backend's auth endpoints.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Typed failure for credential errors (wrong password, unknown account),
/// so the UI can show the backend's message instead of a generic one.
class AuthException implements Exception {
  AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// FastAPI `/api/v1/auth/*` client: 4-step registration with email OTP,
/// login by mobile + password, token refresh, forgot-password, profile
/// (`/auth/me`) and password change.
class AuthApiService {
  AuthApiService(this._client);

  final ApiClient _client;

  // ---- Registration (Steps 1-4) ----

  /// Step 1: creates a pending verification and emails an OTP.
  Future<void> registerStart({
    required String fullName,
    required String mobileNumber,
    required String email,
  }) async {
    try {
      await _client.post('/auth/register/start', body: {
        'full_name': fullName,
        'mobile_number': mobileNumber,
        'email': email,
      });
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  /// Steps 2-3: verify the emailed OTP. The backend marks the verification
  /// as used; the account itself is only created in [setPassword].
  Future<void> verifyRegistrationOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      await _client.post('/auth/register/verify-otp', body: {
        'email': email,
        'otp_code': otpCode,
        'purpose': 'registration',
      });
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  /// Step 4: set the password, creating the account. Returns session tokens.
  Future<AuthTokens> setPassword({
    required String email,
    required String password,
  }) async {
    return _tokened(() => _client.post('/auth/register/set-password', body: {
          'email': email,
          'password': password,
          'confirm_password': password,
        }));
  }

  // ---- Login / session ----

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

  /// The signed-in user's profile (GET /auth/me).
  Future<Map<String, dynamic>> me() async {
    try {
      return await _client.get('/auth/me') as Map<String, dynamic>;
    } on ApiException catch (e) {
      throw AuthException(e.message, statusCode: e.statusCode);
    }
  }

  // ---- Forgot password ----

  Future<void> forgotPasswordStart(String email) async {
    try {
      await _client.post('/auth/forgot-password/start', body: {'email': email});
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  Future<void> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    try {
      await _client.post('/auth/forgot-password/reset', body: {
        'email': email,
        'otp_code': otpCode,
        'new_password': newPassword,
        'confirm_password': newPassword,
      });
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  // ---- Settings ----

  /// Verifies [currentPassword] by attempting a real login. Returns the
  /// error message on failure, null on success.
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
      throw AuthException(e.message);
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
