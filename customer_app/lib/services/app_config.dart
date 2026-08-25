/// Compile-time configuration, passed via `flutter run --dart-define`.
///
/// Examples:
///
///   # Android emulator (host loopback is 10.0.2.2)
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
///
///   # Physical device on the same Wi-Fi (use your PC's LAN IP)
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
///
///   # Force the offline mock data instead of the live API
///   flutter run --dart-define=USE_MOCK_DATA=true
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
