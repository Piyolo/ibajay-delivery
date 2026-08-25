import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../onboarding/permissions_screen.dart';
import 'login_screen.dart';

class CreatePasswordScreen extends StatefulWidget {
  final String email;
  final bool isPasswordReset;

  /// The OTP verified on the previous screen — required by the backend's
  /// forgot-password reset call.
  final String verifiedOtp;

  const CreatePasswordScreen({
    super.key,
    required this.email,
    this.isPasswordReset = false,
    this.verifiedOtp = '',
  });

  @override
  State<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Minimum 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Include at least one uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Include at least one lowercase letter';
    if (!RegExp(r'\d').hasMatch(v)) return 'Include at least one number';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();

    if (widget.isPasswordReset) {
      final auth = context.read<AuthProvider>();
      final ok = await auth.resetPassword(
        email: widget.email,
        otp: widget.verifiedOtp,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.lastAuthError ?? 'Could not reset password. Please try again.'),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successful. Please log in.')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return;
    }

    try {
      await auth.completeRegistration(_passwordController.text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.lastAuthError ?? 'Could not create the account. Please try again.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PermissionsScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isPasswordReset ? 'Reset Password' : 'Create Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.isPasswordReset) ...[
                  const Text('Step 4 of 4', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                ],
                Text(
                  widget.isPasswordReset ? 'Set a new password' : 'Secure your account',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'At least 8 characters, with an uppercase letter, a lowercase letter, and a number.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscure,
                  decoration: const InputDecoration(labelText: 'Confirm Password'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Please confirm your password' : null,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : Text(widget.isPasswordReset ? 'Reset Password' : 'Create Account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
