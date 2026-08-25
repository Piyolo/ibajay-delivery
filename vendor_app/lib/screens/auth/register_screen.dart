import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _storeName = TextEditingController();
  final _storeDescription = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ownerName.dispose();
    _mobile.dispose();
    _email.dispose();
    _storeName.dispose();
    _storeDescription.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final provider = context.read<VendorProvider>();
    final ok = await provider.startRegistration(
      ownerName: _ownerName.text.trim(),
      mobileNumber: _mobile.text.trim(),
      email: _email.text.trim(),
      storeName: _storeName.text.trim(),
      storeDescription: _storeDescription.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.lastAuthError ?? 'Could not send the code')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OtpScreen(email: _email.text.trim())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Your Store')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Owner Information',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Owner Name',
                  controller: _ownerName,
                  hint: 'e.g. Maria Santos',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                _LabeledField(
                  label: 'Mobile Number',
                  controller: _mobile,
                  hint: '09XXXXXXXXX',
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.length < 10) ? 'Enter a valid mobile number' : null,
                ),
                _LabeledField(
                  label: 'Email Address',
                  controller: _email,
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 20),
                const Text('Store Information',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Store Name',
                  controller: _storeName,
                  hint: "e.g. Maria's Kitchen",
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                _LabeledField(
                  label: 'Store Description',
                  controller: _storeDescription,
                  hint: 'What do you serve?',
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(child: _UploadBox(label: 'Logo', icon: Icons.image_outlined)),
                    SizedBox(width: 12),
                    Expanded(child: _UploadBox(label: 'Banner', icon: Icons.panorama_outlined)),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _continue,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
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

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(hintText: hint),
            validator: validator,
          ),
        ],
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  final String label;
  final IconData icon;
  const _UploadBox({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () {
        // TODO: wire up image_picker + Cloudinary upload
      },
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textSecondary),
            const SizedBox(height: 6),
            Text('Upload $label', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
