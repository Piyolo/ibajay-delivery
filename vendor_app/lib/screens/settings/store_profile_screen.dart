import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';

class StoreProfileScreen extends StatefulWidget {
  const StoreProfileScreen({super.key});

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  bool _editing = false;
  bool _uploadingImage = false;
  late TextEditingController _storeName;
  late TextEditingController _description;
  late TextEditingController _address;
  late TextEditingController _contact;

  @override
  void initState() {
    super.initState();
    final vendor = context.read<VendorProvider>().vendor;
    _storeName = TextEditingController(text: vendor.storeName);
    _description = TextEditingController(text: vendor.description);
    _address = TextEditingController(text: vendor.address);
    _contact = TextEditingController(text: vendor.mobileNumber);
  }

  @override
  void dispose() {
    _storeName.dispose();
    _description.dispose();
    _address.dispose();
    _contact.dispose();
    super.dispose();
  }

  void _save() {
    context.read<VendorProvider>().updateProfile(
          storeName: _storeName.text.trim(),
          description: _description.text.trim(),
          address: _address.text.trim(),
          contactNumber: _contact.text.trim(),
        );
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store profile updated')));
  }

  /// Picks an image from the gallery, copies it into the app's persistent
  /// support directory and saves the path on the vendor profile so it
  /// survives restarts. (Swap for a Cloudinary signed upload when the
  /// backend is connected.)
  Future<void> _pickImage({required bool isBanner}) async {
    if (_uploadingImage) return;
    setState(() => _uploadingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: isBanner ? 1600 : 800,
        maxHeight: isBanner ? 900 : 800,
      );
      if (picked == null) return;

      final supportDir = await getApplicationSupportDirectory();
      final imagesDir = Directory('${supportDir.path}${Platform.pathSeparator}store_images');
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

      final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
      final safeExt = ['png', 'jpg', 'jpeg', 'webp'].contains(ext) ? ext : 'jpg';
      final fileName = '${isBanner ? "banner" : "logo"}_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
      final saved = await File(picked.path).copy('${imagesDir.path}${Platform.pathSeparator}$fileName');

      if (!mounted) return;
      await context.read<VendorProvider>().updateProfile(
            bannerUrl: isBanner ? saved.path : null,
            logoUrl: isBanner ? null : saved.path,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(isBanner ? 'Banner updated' : 'Logo updated')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not update image — try again')));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendor = context.watch<VendorProvider>().vendor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Profile'),
        actions: [
          TextButton(
            onPressed: () => _editing ? _save() : setState(() => _editing = true),
            child: Text(_editing ? 'Save' : 'Edit'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          children: [
            // Banner
            Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  color: AppColors.surfaceMuted,
                  child: vendor.bannerUrl.isNotEmpty
                      ? Image.file(
                          File(vendor.bannerUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.panorama_outlined, size: 40, color: AppColors.textSecondary),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.panorama_outlined, size: 40, color: AppColors.textSecondary),
                        ),
                ),
                if (_editing)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: _EditImageChip(
                      label: vendor.bannerUrl.isEmpty ? 'Add Banner' : 'Change Banner',
                      busy: _uploadingImage,
                      onTap: () => _pickImage(isBanner: true),
                    ),
                  ),
                Positioned(
                  left: 16,
                  bottom: -32,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 4),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                    ),
                    child: vendor.logoUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.file(
                              File(vendor.logoUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _logoFallback(vendor.storeName),
                            ),
                          )
                        : _logoFallback(vendor.storeName),
                  ),
                ),
                if (_editing)
                  Positioned(
                    left: 68,
                    bottom: -8,
                    child: _EditImageChip(
                      label: vendor.logoUrl.isEmpty ? 'Add Logo' : 'Change Logo',
                      compact: true,
                      busy: _uploadingImage,
                      onTap: () => _pickImage(isBanner: false),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 44),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field('Store Name', _storeName, editing: _editing, display: vendor.storeName),
                  const SizedBox(height: 16),
                  _field('Description', _description, editing: _editing, display: vendor.description, maxLines: 3),
                  const SizedBox(height: 16),
                  _field('Address', _address, editing: _editing, display: vendor.address, icon: Icons.location_on_outlined),
                  const SizedBox(height: 16),
                  _field('Contact Number', _contact, editing: _editing, display: vendor.mobileNumber, icon: Icons.phone_outlined),
                  const SizedBox(height: 16),
                  _readOnlyRow('Email Address', vendor.email, Icons.email_outlined),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text('${vendor.rating}  ·  ${vendor.totalReviews} reviews',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      if (vendor.isVerified) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.verified, size: 16, color: AppColors.secondary),
                        const SizedBox(width: 4),
                        const Text('Verified', style: TextStyle(color: AppColors.secondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoFallback(String storeName) {
    return CircleAvatar(
      radius: 34,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      child: Text(
        storeName.isNotEmpty ? storeName[0] : '?',
        style: const TextStyle(fontSize: 26, color: AppColors.primary, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    required bool editing,
    required String display,
    int maxLines = 1,
    IconData? icon,
  }) {
    if (!editing) return _readOnlyRow(label, display.isEmpty ? '—' : display, icon);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: controller, maxLines: maxLines),
      ],
    );
  }

  Widget _readOnlyRow(String label, String value, IconData? icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
          ],
        ),
      ],
    );
  }
}

class _EditImageChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool compact;
  final bool busy;

  const _EditImageChip({
    required this.label,
    required this.onTap,
    this.compact = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: busy ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 4 : 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
