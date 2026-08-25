import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_preferences_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/location_provider.dart';
import '../providers/vendor_provider.dart';
import '../theme/app_theme.dart';
import 'auth/landing_screen.dart';
import 'location/location_setup_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Defer to after the first frame: the restore/load calls notify
    // listeners, which is illegal during the initial build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prepareAndNavigate();
    });
  }

  Future<void> _prepareAndNavigate() async {
    // Restore locally-persisted state (session, addresses, favorites,
    // preferences) and load vendor/menu/review data, holding the splash
    // for at least a beat so the logo doesn't just flash.
    final minimumDisplay = Future.delayed(const Duration(milliseconds: 1200));
    final dataLoad = context.read<VendorProvider>().load();
    final restores = Future.wait([
      context.read<AuthProvider>().restoreSession(),
      context.read<LocationProvider>().restore(),
      context.read<FavoritesProvider>().restore(),
      context.read<AppPreferencesProvider>().restore(),
    ]);
    await Future.wait([minimumDisplay, dataLoad, restores]);
    if (mounted) _navigate();
  }

  void _navigate() {
    final auth = context.read<AuthProvider>();
    Widget next;
    if (auth.status == AuthStatus.signedIn) {
      next = auth.hasSavedLocation ? const MainShell() : const LocationSetupScreen();
    } else {
      next = const LandingScreen();
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
              Image.asset('assets/images/logo.png', width: 240, height: 240),
              const SizedBox(height: 20),
              const Text(
                'Order from local stores near you.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
