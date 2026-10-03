import 'package:shared_preferences/shared_preferences.dart';

/// Thin async wrapper around SharedPreferences for the customer app's
/// locally-persisted state (session, addresses, favorites, preferences).
///
/// During the mock stage this stands in for the backend; when the FastAPI
/// API is connected, swap call sites for real requests and keep this only
/// for the auth token cache.
class PreferencesService {
  PreferencesService._();

  static SharedPreferences? _instance;

  static Future<SharedPreferences> get _prefs async =>
      _instance ??= await SharedPreferences.getInstance();

  // ---- Generic helpers ----

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

  static Future<List<String>> getStringList(String key) async {
    final p = await _prefs;
    return p.getStringList(key) ?? const [];
  }

  static Future<void> setStringList(String key, List<String> value) async {
    final p = await _prefs;
    await p.setStringList(key, value);
  }

  // ---- Keys ----
  //
  // Per-user data (addresses, favorites, flags) is namespaced by account id
  // so switching accounts on one device never shares or leaks data between
  // users. Session keys are global by nature.

  static const kSessionUser = 'auth.session_user';
  static const kAccessToken = 'auth.access_token';
  static const kRefreshToken = 'auth.refresh_token';

  static String kHasSavedLocationFor(String uid) => 'auth.$uid.has_saved_location';

  static String kAddressesFor(String uid) => 'location.$uid.addresses';
  static String kActiveAddressIdFor(String uid) => 'location.$uid.active_address_id';

  static String kFavoriteVendorsFor(String uid) => 'favorites.$uid.vendors';
  static String kFavoriteFoodsFor(String uid) => 'favorites.$uid.foods';

  static const kOrderNotifs = 'prefs.order_notifs';
  static const kChatNotifs = 'prefs.chat_notifs';
  static const kPromoNotifs = 'prefs.promo_notifs';
  static const kShareLocation = 'prefs.share_location';
}
