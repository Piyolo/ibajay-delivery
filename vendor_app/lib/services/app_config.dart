/// Compile-time configuration, passed via `flutter run --dart-define`.
///
///   flutter run --dart-define=API_BASE_URL=https://ibajay-delivery.onrender.com
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ibajay-delivery.onrender.com',
  );
}
