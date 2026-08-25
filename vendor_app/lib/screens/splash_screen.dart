import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import 'auth/login_screen.dart';
import 'main_shell.dart';
import 'onboarding/store_setup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _prepareAndNavigate();
  }

  Future<void> _prepareAndNavigate() async {
    // Restore the persisted session and store configuration, holding the
    // splash for at least a beat so the logo doesn't just flash.
    final minimumDisplay = Future.delayed(const Duration(milliseconds: 1000));
    final restore = context.read<VendorProvider>().restoreSession();
    await Future.wait([minimumDisplay, restore]);
    if (!mounted) return;

    final vendorProvider = context.read<VendorProvider>();
    Widget next;
    if (vendorProvider.isAuthenticated) {
      next = vendorProvider.hasCompletedStoreSetup
          ? const MainShell()
          : const StoreSetupScreen();
    } else {
      next = const LoginScreen();
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/ibajay_eats_logo.png', width: 200, height: 200),
              const SizedBox(height: 20),
              const Text(
                'Ibajay Eats',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Vendor App',
                style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
