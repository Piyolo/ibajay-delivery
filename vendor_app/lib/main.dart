import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'providers/menu_provider.dart';
import 'providers/order_provider.dart';
import 'providers/promotions_provider.dart';
import 'providers/vendor_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'theme/app_theme.dart';

/// Global navigator key so the auth listener can bounce a dead session
/// back to the login screen from anywhere in the tree.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const VendorApp());
}

class VendorApp extends StatefulWidget {
  const VendorApp({super.key});

  @override
  State<VendorApp> createState() => _VendorAppState();
}

class _VendorAppState extends State<VendorApp> {
  // One shared ApiClient (the auth token lives on the client instance) and
  // providers created exactly once — rebuilding the root widget must never
  // recreate them or the session/inbox/menu state would be wiped.
  late final ApiClient _sharedClient;
  late final VendorProvider _vendor;
  late final OrderProvider _orders;
  late final MenuProvider _menu;
  late final PromotionsProvider _promotions;
  late final ChatProvider _chat;

  @override
  void initState() {
    super.initState();
    _sharedClient = ApiClient();
    _vendor = VendorProvider(apiClient: _sharedClient);
    _orders = OrderProvider(apiClient: _sharedClient);
    _menu = MenuProvider(apiClient: _sharedClient);
    _promotions = PromotionsProvider(apiClient: _sharedClient);
    _chat = ChatProvider(apiClient: _sharedClient);
    _vendor.addListener(_onVendorAuthChanged);
  }

  /// Tracks the last known auth state so a session that dies MID-USE
  /// (revoked token, failed refresh) bounces the vendor back to login
  /// instead of leaving stale screens behind. Splash-driven sign-outs
  /// don't need this (routing happens there), but they're harmless.
  bool _wasAuthenticated = false;

  void _onVendorAuthChanged() {
    final authed = _vendor.isAuthenticated;
    if (_wasAuthenticated && !authed) {
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
    _wasAuthenticated = authed;
  }

  @override
  void dispose() {
    _vendor.removeListener(_onVendorAuthChanged);
    _sharedClient.dispose();
    for (final n in [_vendor, _orders, _menu, _promotions, _chat]) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _vendor),
        ChangeNotifierProvider.value(value: _orders),
        ChangeNotifierProvider.value(value: _menu),
        ChangeNotifierProvider.value(value: _promotions),
        ChangeNotifierProvider.value(value: _chat),
      ],
      child: MaterialApp(
        title: 'Ibajay Eats — Vendor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        navigatorKey: appNavigatorKey,
        home: const SplashScreen(),
      ),
    );
  }
}
