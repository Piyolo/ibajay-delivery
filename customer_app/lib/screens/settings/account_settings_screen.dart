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
    showDialog<void>(
      context: context,
      builder: (_) => _EditFieldDialog(
        title: title,
        label: label,
        initialValue: initialValue,
        keyboardType: keyboardType,
        save: save,
      ),
    );
  }

  /// Email changes require OTP confirmation: collect the new address,
  /// "send" the code, then verify on the dedicated screen.
  void _startEmailChange(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _ChangeEmailDialog(),
    );
  }
}

class _EditFieldDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;
  final TextInputType keyboardType;
  final Future<void> Function(String value) save;

  const _EditFieldDialog({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.keyboardType,
    required this.save,
  });

  @override
  State<_EditFieldDialog> createState() => _EditFieldDialogState();
}

class _EditFieldDialogState extends State<_EditFieldDialog> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _ctrl.text.trim();
    if (value.isEmpty) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    await widget.save(value);
    messenger.showSnackBar(SnackBar(content: Text('${widget.title} — saved')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: TextField(
          controller: _ctrl,
          keyboardType: widget.keyboardType,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.label),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _ChangeEmailDialog extends StatefulWidget {
  const _ChangeEmailDialog();

  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  late final TextEditingController _ctrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _ctrl.text.trim();
    if (value.isEmpty || !value.contains('@')) return;
    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final demoOtp = await auth.startEmailChange(value);
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VerifyEmailChangeScreen(newEmail: value, demoOtp: demoOtp),
      ));
    } on Exception {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('That is already your current email')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = context.watch<AuthProvider>().currentUser?.email ?? '';

    return AlertDialog(
      title: const Text('Change Email'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current: $currentEmail',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'New email address'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send Code'),
        ),
      ],
    );
  }
}
