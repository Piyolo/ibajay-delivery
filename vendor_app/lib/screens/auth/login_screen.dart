import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/vendor_provider.dart';
import '../../services/auth_api_service.dart';
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
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final vendorProvider = context.read<VendorProvider>();
    final ok = await vendorProvider.signIn(
      mobileNumber: _mobileController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = ok ? null : (vendorProvider.lastAuthError ?? 'Could not sign in');
    });
    if (!ok) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => vendorProvider.hasCompletedStoreSetup
            ? const MainShell()
            : const StoreSetupScreen(),
      ),
    );
  }

  /// Real forgot-password flow: email -> OTP -> new password, against
  /// POST /auth/forgot-password/start and /reset.
  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    int step = 0; // 0=email, 1=otp+new password
    bool busy = false;
    String? error;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(step == 0 ? 'Reset Password' : 'Check your email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (step == 0) ...[
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Account email', hintText: 'you@example.com'),
                ),
              ] else ...[
                TextField(
                  controller: otpCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '6-digit code from email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'New password (8+ chars, Aa1)'),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child:
                      Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      setDialogState(() {
                        busy = true;
                        error = null;
                      });
                      final auth = AuthApiService(context.read<VendorProvider>().client);
                      try {
                        if (step == 0) {
                          await auth.forgotPasswordStart(emailCtrl.text.trim());
                          setDialogState(() => step = 1);
                        } else {
                          await auth.resetPassword(
                            email: emailCtrl.text.trim(),
                            otpCode: otpCtrl.text.trim(),
                            newPassword: passwordCtrl.text,
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          messenger.showSnackBar(const SnackBar(
                              content: Text('Password reset — you can now log in')));
                        }
                      } on AuthException catch (e) {
                        setDialogState(() => error = e.message);
                      }
                      setDialogState(() => busy = false);
                    },
              child: Text(busy ? 'Sending…' : (step == 0 ? 'Send Code' : 'Reset Password')),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      emailCtrl.dispose();
      otpCtrl.dispose();
      passwordCtrl.dispose();
    });
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
                const Text('Mobile Number', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: '09123456789'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter your mobile number' : null,
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
                      (v == null || v.isEmpty) ? 'Password is required' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text('Forgot Password?'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text('Login'),
                  ),
                ),
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