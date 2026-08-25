import 'package:flutter/material.dart';

import '../services/preferences_service.dart';

/// Notification & privacy toggles from the Settings screen.
/// All values persist locally and are restored at app start.
class AppPreferencesProvider extends ChangeNotifier {
  bool orderNotifs = true;
  bool chatNotifs = true;
  bool promoNotifs = false;
  bool shareLocation = true;

  /// Restores saved toggles. Call once at app start (splash).
  Future<void> restore() async {
    orderNotifs = await PreferencesService.getBool(PreferencesService.kOrderNotifs, fallback: true);
    chatNotifs = await PreferencesService.getBool(PreferencesService.kChatNotifs, fallback: true);
    promoNotifs = await PreferencesService.getBool(PreferencesService.kPromoNotifs, fallback: false);
    shareLocation =
        await PreferencesService.getBool(PreferencesService.kShareLocation, fallback: true);
    notifyListeners();
  }

  Future<void> setOrderNotifs(bool v) async {
    orderNotifs = v;
    notifyListeners();
    await PreferencesService.setBool(PreferencesService.kOrderNotifs, v);
  }

  Future<void> setChatNotifs(bool v) async {
    chatNotifs = v;
    notifyListeners();
    await PreferencesService.setBool(PreferencesService.kChatNotifs, v);
  }

  Future<void> setPromoNotifs(bool v) async {
    promoNotifs = v;
    notifyListeners();
    await PreferencesService.setBool(PreferencesService.kPromoNotifs, v);
  }

  Future<void> setShareLocation(bool v) async {
    shareLocation = v;
    notifyListeners();
    await PreferencesService.setBool(PreferencesService.kShareLocation, v);
  }
}
