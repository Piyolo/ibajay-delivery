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
    // Restore locally-persisted state (session, preferences) first,
    // holding the splash for at least a beat so the logo doesn't just
    // flash. Vendor loading never throws — a failure surfaces on Home with
    // a retry button instead of hanging here.
    final auth = context.read<AuthProvider>();
    final location = context.read<LocationProvider>();
    final vendors = context.read<VendorProvider>();
    final minimumDisplay = Future.delayed(const Duration(milliseconds: 1200));
    await Future.wait([
      minimumDisplay,
      auth.restoreSession(),
      context.read<AppPreferencesProvider>().restore(),
    ]);
    if (!mounted) return;

    // Bind per-user data to the signed-in account (or clear it when
    // signed out), then pull the authoritative address list.
    if (auth.status == AuthStatus.signedIn && auth.currentUser?.id.isNotEmpty == true) {
      final uid = auth.currentUser!.id;
      await Future.wait([
        location.attachUser(uid),
        context.read<FavoritesProvider>().attachUser(uid),
      ]);
    } else {
      location.detachUser();
      context.read<FavoritesProvider>().detachUser();
    }

    await vendors.load(refLat: location.referenceLat, refLng: location.referenceLng);
    if (!mounted) return;
    _navigate();
  }

  void _navigate() {
    final auth = context.read<AuthProvider>();
    final location = context.read<LocationProvider>();
    Widget next;
    if (auth.status == AuthStatus.signedIn) {
      // A user who already saved an address (locally or on the server)
      // goes straight in; only genuinely-new accounts see setup again.
      final hasLocation =
          location.addresses.isNotEmpty || auth.hasSavedLocation;
      next = hasLocation ? const MainShell() : const LocationSetupScreen();
    } else {
      next = const LandingScreen();
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
