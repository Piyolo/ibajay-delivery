import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_preferences_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/location_provider.dart';
import 'providers/order_provider.dart';
import 'providers/vendor_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const IbajayEatsApp());
}

class IbajayEatsApp extends StatelessWidget {
  const IbajayEatsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => VendorProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => AppPreferencesProvider()),
      ],
      child: MaterialApp(
        title: 'Ibajay Eats',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}
