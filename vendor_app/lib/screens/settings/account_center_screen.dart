import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';

/// Account Center — the vendor's personal account (identity & security),
/// deliberately separate from store configuration. Persists every change.
class AccountCenterScreen extends StatelessWidget {
  const AccountCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vendor = context.watch<VendorProvider>().vendor;

    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Account header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      vendor.ownerName.isNotEmpty ? vendor.ownerName[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vendor.ownerName.isEmpty ? 'Store Owner' : vendor.ownerName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(vendor.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text('Store: ${vendor.storeName}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Account Information'),
          _tile(
            context,
            Icons.person_outline,
            'Owner Name',
            subtitle: vendor.ownerName,
            onTap: () => _editField(
              context,
              title: 'Owner Name',
              label: 'Full name',
              initialValue: vendor.ownerName,
              keyboardType: TextInputType.name,
              save: (v) => context.read<VendorProvider>().updateProfile(ownerName: v),
            ),
          ),
          _tile(
            context,
            Icons.mail_outline,
            'Email Address',
            subtitle: vendor.email,
            onTap: () => _editField(
              context,
              title: 'Email Address',
              label: 'Email',
              initialValue: vendor.email,
              keyboardType: TextInputType.emailAddress,
              save: (v) => context.read<VendorProvider>().updateProfile(email: v),
            ),
          ),
          _tile(
            context,
            Icons.phone_outlined,
            'Mobile Number',
            subtitle: vendor.mobileNumber,
            onTap: () => _editField(
              context,
              title: 'Mobile Number',
              label: 'Mobile number',
              initialValue: vendor.mobileNumber,
              keyboardType: TextInputType.phone,
              save: (v) => context.read<VendorProvider>().updateProfile(contactNumber: v),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Security'),
          _tile(
            context,
            Icons.lock_outline,
            'Change Password',
            subtitle: 'Requires your current password',
            onTap: () => _changePassword(context),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () {
              context.read<VendorProvider>().signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout, color: AppColors.danger),
            label: const Text('Log Out', style: TextStyle(color: AppColors.danger)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title, {
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null && subtitle.isNotEmpty
            ? Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }

  void _editField(
    BuildContext context, {
    required String title,
    required String label,
    required String initialValue,
    required TextInputType keyboardType,
    required Future<void> Function(String value) save,
  }) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(dialogContext).pop();
              await save(value);
              messenger.showSnackBar(SnackBar(content: Text('$title — saved')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Two-step dialog: verify current password first, then set the new one.
  void _changePassword(BuildContext context) {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool verified = false;
    bool verifying = false;
    String? verifyError;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!verified) ...[
                TextField(
                  controller: currentController,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Current password'),
                ),
                if (verifyError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(verifyError!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ),
              ] else ...[
                const Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: AppColors.success),
                    SizedBox(width: 6),
                    Text('Current password verified',
                        style: TextStyle(color: AppColors.success, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newController,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'New password (min. 8 characters)'),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm new password'),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (!verified) Navigator.of(context).pop(); // cancel entirely
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: verifying
                  ? null
                  : !verified
                      ? () async {
                          if (currentController.text.isEmpty) return;
                          setDialogState(() => verifying = true);
                          final provider = context.read<VendorProvider>();
                          final ok = await provider.verifyPassword(currentController.text);
                          setDialogState(() {
                            verifying = false;
                            verified = ok;
                            verifyError = ok ? null : 'Incorrect current password';
                          });
                        }
                      : (newController.text.length >= 8 && newController.text == confirmController.text)
                          ? () async {
                              final provider = context.read<VendorProvider>();
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.of(dialogContext).pop();
                              await provider.changePassword(newController.text);
                              messenger.showSnackBar(
                                  const SnackBar(content: Text('Password updated')));
                            }
                          : null,
              child: Text(verifying
                  ? 'Verifying…'
                  : verified
                      ? 'Save New Password'
                      : 'Verify'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 13)),
    );
  }
}
