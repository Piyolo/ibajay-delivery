import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/vendor_provider.dart';
import 'providers/order_provider.dart';
import 'providers/menu_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const VendorApp());
}

class VendorApp extends StatelessWidget {
  const VendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VendorProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
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
