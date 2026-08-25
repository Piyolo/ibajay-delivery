import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hero_illustration.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const HeroIllustration(size: 200),
              const SizedBox(height: 20),
              Image.asset('assets/images/logo.png', width: 130, height: 130),
              const SizedBox(height: 10),
              const Text(
                'Ibajay Eats',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Order from local stores near you.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: const Text('Login'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text('Sign Up'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
