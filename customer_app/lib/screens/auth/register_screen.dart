import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    await auth.startRegistration(
      fullName: _nameController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      email: _emailController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (auth.lastAuthError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.lastAuthError!)),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OtpScreen(email: _emailController.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Step 1 of 4', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                const Text(
                  "Let's get to know you",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name', hintText: 'Juan Dela Cruz'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Number', hintText: '09123456789'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Mobile number is required';
                    if (!RegExp(r'^09\d{9}$').hasMatch(v.trim())) return 'Enter a valid PH mobile number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email Address', hintText: 'juan@gmail.com'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _continue,
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text('Continue'),
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
