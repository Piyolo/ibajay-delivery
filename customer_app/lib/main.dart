import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_preferences_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/location_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/order_provider.dart';
import 'providers/vendor_provider.dart';
import 'screens/auth/landing_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

/// Global navigator key so the auth listener can bounce a dead session
/// back to the landing screen from anywhere in the tree.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const IbajayEatsApp());
}

class IbajayEatsApp extends StatefulWidget {
  const IbajayEatsApp({super.key});

  @override
  State<IbajayEatsApp> createState() => _IbajayEatsAppState();
}

class _IbajayEatsAppState extends State<IbajayEatsApp> {
  // Providers are created exactly once, in State — never inside build().
  // Rebuilding the root widget (keyboard, text scale, MediaQuery changes)
  // must not recreate the ChangeNotifiers or the session, cart, orders,
  // and chats would be wiped mid-use.
  late final AuthProvider _auth;
  late final LocationProvider _location;
  late final VendorProvider _vendors;
  late final OrderProvider _orders;
  late final ChatProvider _chat;
  late final CartProvider _cart;
  late final FavoritesProvider _favorites;
  late final AppPreferencesProvider _prefs;
  late final NotificationProvider _notifications;
  late final List<ChangeNotifier> _notifiers;

  @override
  void initState() {
    super.initState();
    _auth = AuthProvider();
    // LocationProvider MUST share the auth client — its address
    // sync/save calls are authenticated, and a private client never
    // receives the token (the address book silently stopped syncing
    // and setup re-appeared on returning accounts without this).
    _location = LocationProvider(apiClient: _auth.client);
    _vendors = VendorProvider();
    _orders = OrderProvider(apiClient: _auth.client, vendors: _vendors);
    // Chat shares the auth provider's ApiClient so its requests carry
    // the session token.
    _chat = ChatProvider(apiClient: _auth.client);
    _cart = CartProvider();
    _favorites = FavoritesProvider();
    _prefs = AppPreferencesProvider();
    // Shares the auth client so /notifications carries the session token.
    _notifications = NotificationProvider(apiClient: _auth.client);
    // Order status changes push new notifications server-side — refresh
    // the bell whenever a status actually changes (see OrderProvider).
    _orders.onOrdersChanged = _notifications.refresh;
    _notifiers = [
      _auth, _location, _vendors, _orders, _chat, _cart, _favorites, _prefs,
      _notifications,
    ];

    // Once a session exists (fresh login or restored), pull the saved
    // address book from the backend so checkout has real address IDs.
    _auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    // Per-user data follows the signed-in account; signing out detaches
    // it so another account on this device starts clean.
    if (_auth.status == AuthStatus.signedIn && _auth.currentUser?.id.isNotEmpty == true) {
      final uid = _auth.currentUser!.id;
      _location.attachUser(uid);
      _favorites.attachUser(uid);
      _notifications.attachUser(uid);
      _orders.loadOrders();
    } else if (_auth.status == AuthStatus.signedOut) {
      _location.detachUser();
      _favorites.detachUser();
      _notifications.detachUser();
      _orders.stopWatching();
      // Cart and conversations belong to the account too.
      _cart.clear();
      _chat.reset();
      // A session that died MID-USE (revoked token, failed refresh)
      // lands here while the user is deep in the app — send them to the
      // landing screen instead of leaving stale screens behind. The
      // manual Sign Out button navigates itself, so only auto-sign-outs
      // (app start / dead session) need this; either way pushing the
      // same destination is harmless and idempotent.
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LandingScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    for (final n in _notifiers) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _location),
        ChangeNotifierProvider.value(value: _vendors),
        ChangeNotifierProvider.value(value: _orders),
        ChangeNotifierProvider.value(value: _chat),
        ChangeNotifierProvider.value(value: _cart),
        ChangeNotifierProvider.value(value: _favorites),
        ChangeNotifierProvider.value(value: _prefs),
        ChangeNotifierProvider.value(value: _notifications),
      ],
      child: MaterialApp(
        title: 'Ibajay Eats',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        navigatorKey: appNavigatorKey,
        home: const SplashScreen(),
      ),
    );
  }
}
