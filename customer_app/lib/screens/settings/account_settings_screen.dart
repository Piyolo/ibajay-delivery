import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'change_password_screen.dart';
import 'verify_email_change_screen.dart';

/// Account-level settings (credentials & identity), separate from the
/// general profile screen: name, email (OTP-confirmed), mobile number and
/// password (current-password confirmed).
class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel('Account Information'),
          _tile(
            Icons.person_outline,
            'Change Name',
            subtitle: user?.fullName ?? '',
            onTap: () => _editField(
              context,
              title: 'Change Name',
              label: 'Full name',
              initialValue: user?.fullName ?? '',
              keyboardType: TextInputType.name,
              save: (v) => context.read<AuthProvider>().updateProfile(fullName: v),
            ),
          ),
          _tile(
            Icons.mail_outline,
            'Change Email',
            subtitle: user?.email ?? '',
            onTap: () => _startEmailChange(context),
          ),
          _tile(
            Icons.phone_outlined,
            'Change Mobile Number',
            subtitle: user?.mobileNumber ?? '',
            onTap: () => _editField(
              context,
              title: 'Change Mobile Number',
              label: 'Mobile number',
              initialValue: user?.mobileNumber ?? '',
              keyboardType: TextInputType.phone,
              save: (v) => context.read<AuthProvider>().updateProfile(mobileNumber: v),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel('Security'),
          _tile(
            Icons.lock_outline,
            'Change Password',
            subtitle: 'Requires your current password',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 13)),
      );

  Widget _tile(IconData icon, String title, {String? subtitle, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null && subtitle.isNotEmpty
            ? Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: const Icon(Icons.chevron_right, size: 20),
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

  /// Email changes require OTP confirmation: collect the new address,
  /// "send" the code, then verify on the dedicated screen.
  void _startEmailChange(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current: ${auth.currentUser?.email ?? ''}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'New email address'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final value = controller.text.trim();
              if (value.isEmpty || !value.contains('@')) return;
              try {
                final demoOtp = await auth.startEmailChange(value);
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!context.mounted) return;
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VerifyEmailChangeScreen(newEmail: value, demoOtp: demoOtp),
                ));
              } on Exception {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('That is already your current email')),
                );
              }
            },
            child: const Text('Send Code'),
          ),
        ],
      ),
    );
  }
}
