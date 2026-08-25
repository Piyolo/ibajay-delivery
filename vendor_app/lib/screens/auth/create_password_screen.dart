import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../onboarding/store_setup_screen.dart';

class CreatePasswordScreen extends StatefulWidget {
  const CreatePasswordScreen({super.key});

  @override
  State<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  bool get _hasMinLength => _password.text.length >= 8;
  bool get _hasUppercase => _password.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _password.text.contains(RegExp(r'[a-z]'));
  bool get _hasNumber => _password.text.contains(RegExp(r'[0-9]'));

  String? _validatePassword(String? v) {
    if (v == null || !_hasMinLength || !_hasUppercase || !_hasLowercase || !_hasNumber) {
      return 'Password does not meet requirements';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    // TODO: POST /auth/register to create the vendor account
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StoreSetupScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Password', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  onChanged: (_) => setState(() {}),
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    hintText: 'Create a password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Confirm Password', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  decoration: const InputDecoration(hintText: 'Re-enter your password'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                _requirement('At least 8 characters', _hasMinLength),
                _requirement('One uppercase letter', _hasUppercase),
                _requirement('One lowercase letter', _hasLowercase),
                _requirement('One number', _hasNumber),
                const SizedBox(height: 28),
                ElevatedButton(onPressed: _submit, child: const Text('Create Account')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _requirement(String label, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: met ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: met ? AppColors.success : AppColors.textSecondary)),
        ],
      ),
    );
  }
}
