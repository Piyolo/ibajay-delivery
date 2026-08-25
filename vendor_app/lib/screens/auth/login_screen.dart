import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import '../main_shell.dart';
import '../onboarding/store_setup_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'maria@ibajayeats.test');
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    final vendorProvider = context.read<VendorProvider>();
    vendorProvider.signIn(password: _passwordController.text);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => vendorProvider.hasCompletedStoreSetup
            ? const MainShell()
            : const StoreSetupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Image.asset('assets/images/ibajay_eats_logo.png', width: 110, height: 110),
                ),
                const SizedBox(height: 24),
                const Text('Welcome back',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to manage your store, menu, and orders.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                const Text('Email Address', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'you@example.com'),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email address' : null,
                ),
                const SizedBox(height: 18),
                const Text('Password', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Password is required' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _login, child: const Text('Login')),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have a store yet?",
                        style: TextStyle(color: AppColors.textSecondary)),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      child: const Text('Register your store'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}