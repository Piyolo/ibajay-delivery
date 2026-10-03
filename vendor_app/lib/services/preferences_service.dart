import 'package:shared_preferences/shared_preferences.dart';

/// Thin async wrapper around SharedPreferences for the vendor app's
/// locally-persisted state: the auth session tokens plus a cached store
/// profile and setup flag so splash routing works offline.
class PreferencesService {
  PreferencesService._();

  static SharedPreferences? _instance;

  static Future<SharedPreferences> get _prefs async =>
      _instance ??= await SharedPreferences.getInstance();

  static Future<String?> getString(String key) async => (await _prefs).getString(key);

  static Future<void> setString(String key, String value) async {
    final p = await _prefs;
    await p.setString(key, value);
  }

  static Future<void> remove(String key) async {
    final p = await _prefs;
    await p.remove(key);
  }

  static Future<bool> getBool(String key, {bool fallback = false}) async {
    final p = await _prefs;
    return p.getBool(key) ?? fallback;
  }

  static Future<void> setBool(String key, bool value) async {
    final p = await _prefs;
    await p.setBool(key, value);
  }

  // ---- Keys ----

  static const kAccessToken = 'vendor.access_token';
  static const kRefreshToken = 'vendor.refresh_token';
  static const kOwnerMobile = 'vendor.owner_mobile';
  static const kSetupDone = 'vendor.setup_done';
  static const kProfile = 'vendor.profile';
}
