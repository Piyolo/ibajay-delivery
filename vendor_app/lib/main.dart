import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/vendor_provider.dart';
import 'providers/order_provider.dart';
import 'providers/menu_provider.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const VendorApp());
}

class VendorApp extends StatelessWidget {
  const VendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    // One shared ApiClient: the auth token lives on the client instance,
    // so every provider must send requests through the same one.
    final sharedClient = ApiClient();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VendorProvider(apiClient: sharedClient)),
        ChangeNotifierProvider(create: (_) => OrderProvider(apiClient: sharedClient)),
        ChangeNotifierProvider(create: (_) => MenuProvider(apiClient: sharedClient)),
      ],
      child: MaterialApp(
        title: 'Ibajay Eats — Vendor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}
