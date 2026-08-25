/// Compile-time configuration, passed via `flutter run --dart-define`.
///
///   flutter run --dart-define=API_BASE_URL=https://ibajay-delivery.onrender.com
///   flutter run --dart-define=USE_MOCK_DATA=true   # offline mock mode
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const bool useMockData = bool.fromEnvironment(
    'USE_MOCK_DATA',
    defaultValue: false,
  );
}
