import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart';
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
  String? _logoUrl;
  String? _bannerUrl;
  String? _uploading; // 'logo' | 'banner' | null

  @override
  void dispose() {
    _ownerName.dispose();
    _mobile.dispose();
    _email.dispose();
    _storeName.dispose();
    _storeDescription.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool isBanner}) async {
    if (_loading || _uploading != null) return;
    final provider = context.read<VendorProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _uploading = isBanner ? 'banner' : 'logo');
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: isBanner ? 1600 : 800,
        maxHeight: isBanner ? 900 : 800,
      );
      if (picked == null) return;
      if (!mounted) return;
      // Uploads need an authenticated account — keep the local file and
      // upload it during store creation instead.
      setState(() {
        if (isBanner) {
          _bannerUrl = picked.path;
        } else {
          _logoUrl = picked.path;
        }
      });
      provider.setPendingImages(logoPath: _logoUrl, bannerPath: _bannerUrl);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not pick the image — try again')),
      );
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
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
                Row(
                  children: [
                    Expanded(
                      child: _UploadBox(
                        label: 'Logo',
                        icon: Icons.image_outlined,
                        previewUrl: _logoUrl,
                        isUploading: _uploading == 'logo',
                        onTap: () => _pickImage(isBanner: false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _UploadBox(
                        label: 'Banner',
                        icon: Icons.panorama_outlined,
                        previewUrl: _bannerUrl,
                        isUploading: _uploading == 'banner',
                        onTap: () => _pickImage(isBanner: true),
                      ),
                    ),
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have a store with us?',
                        style: TextStyle(color: AppColors.textSecondary)),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      child: const Text('Sign in instead'),
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
  final String? previewUrl;
  final bool isUploading;
  final VoidCallback onTap;

  const _UploadBox({
    required this.label,
    required this.icon,
    this.previewUrl,
    this.isUploading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: isUploading ? null : onTap,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: previewUrl != null ? AppColors.primary : AppColors.border,
            width: previewUrl != null ? 1.5 : 1,
            style: BorderStyle.solid,
          ),
          image: previewUrl != null && previewUrl!.startsWith('http')
              ? DecorationImage(image: NetworkImage(previewUrl!), fit: BoxFit.cover)
              : (previewUrl != null
                  ? DecorationImage(
                      image: FileImage(File(previewUrl!)), fit: BoxFit.cover)
                  : null),
        ),
        child: isUploading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.2))
            : previewUrl != null
                ? null
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: AppColors.textSecondary),
                      const SizedBox(height: 6),
                      Text('Upload $label',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
      ),
    );
  }
}
