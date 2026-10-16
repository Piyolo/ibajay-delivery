import 'package:flutter/material.dart';

import '../services/preferences_service.dart';

/// Notification & privacy toggles from the Settings screen.
///
/// Values are stored at TWO levels: the original device-level keys (what a
/// fresh app start restores, shared state for the pre-login Settings
/// screen) and — once a user signs in — a per-user override so two
/// accounts on one phone keep their own choices (they previously bled into
/// each other through the single global key).
class AppPreferencesProvider extends ChangeNotifier {
  bool orderNotifs = true;
  bool chatNotifs = true;
  bool promoNotifs = false;
  bool shareLocation = true;

  String? _uid;

  String _userKey(String deviceKey) => '$deviceKey.user=$_uid';

  /// Restores saved toggles. Called once at app start (splash) and again
  /// on sign-out, always against the device-level keys.
  Future<void> restore() async {
    orderNotifs = await PreferencesService.getBool(PreferencesService.kOrderNotifs, fallback: true);
    chatNotifs = await PreferencesService.getBool(PreferencesService.kChatNotifs, fallback: true);
    promoNotifs = await PreferencesService.getBool(PreferencesService.kPromoNotifs, fallback: false);
    shareLocation =
        await PreferencesService.getBool(PreferencesService.kShareLocation, fallback: true);
    notifyListeners();
  }

  /// Loads the signed-in user's overrides on top of the device values.
  /// Falls back gracefully for accounts that predate per-user storage.
  Future<void> attachUser(String uid) async {
    _uid = uid;
    orderNotifs = await _deviceOrUser(PreferencesService.kOrderNotifs, fallback: orderNotifs);
    chatNotifs = await _deviceOrUser(PreferencesService.kChatNotifs, fallback: chatNotifs);
    promoNotifs = await _deviceOrUser(PreferencesService.kPromoNotifs, fallback: promoNotifs);
    shareLocation =
        await _deviceOrUser(PreferencesService.kShareLocation, fallback: shareLocation);
    notifyListeners();
  }

  Future<bool> _deviceOrUser(String deviceKey, {required bool fallback}) async {
    if (_uid != null) {
      final userValue =
          await PreferencesService.getBool(_userKey(deviceKey), fallback: fallback);
      if (userValue != fallback) return userValue;
    }
    // No per-user value yet: keep whatever the device-level value is.
    return fallback;
  }

  /// Signs out: drop the account and fall back to the device-level state.
  Future<void> detachUser() async {
    _uid = null;
    await restore();
  }

  Future<void> setOrderNotifs(bool v) async {
    orderNotifs = v;
    notifyListeners();
    await _write(PreferencesService.kOrderNotifs, v);
  }

  Future<void> setChatNotifs(bool v) async {
    chatNotifs = v;
    notifyListeners();
    await _write(PreferencesService.kChatNotifs, v);
  }

  Future<void> setPromoNotifs(bool v) async {
    promoNotifs = v;
    notifyListeners();
    await _write(PreferencesService.kPromoNotifs, v);
  }

  Future<void> setShareLocation(bool v) async {
    shareLocation = v;
    notifyListeners();
    await _write(PreferencesService.kShareLocation, v);
  }

  /// Writes the device-level key (keeps pre-login behavior) and, when a
  /// user is signed in, the per-user override.
  Future<void> _write(String deviceKey, bool v) async {
    await PreferencesService.setBool(deviceKey, v);
    if (_uid != null) {
      await PreferencesService.setBool(_userKey(deviceKey), v);
    }
  }
}
