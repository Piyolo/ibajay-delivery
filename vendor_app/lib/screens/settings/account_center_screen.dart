import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';

/// Account Center — the vendor''s personal account (identity & security),
/// deliberately separate from store configuration.
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
                        Text(vendor.email,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => _EditFieldDialog(
                title: 'Owner Name',
                label: 'Full name',
                initialValue: vendor.ownerName,
                keyboardType: TextInputType.name,
                // Wait for the server result; lastError is null only when
                // the account update really went through.
                save: (v) async {
                  final provider = context.read<VendorProvider>();
                  await provider.updateProfile(ownerName: v);
                  return provider.lastError;
                },
              ),
            ),
          ),
          // Email and mobile are account identifiers the backend does not
          // accept edits for — shown read-only instead of a dialog that
          // fakes a save.
          _tile(
            context,
            Icons.mail_outline,
            'Email Address',
            subtitle: vendor.email,
            hint: 'Contact support to change your email',
          ),
          _tile(
            context,
            Icons.phone_outlined,
            'Mobile Number',
            subtitle: vendor.mobileNumber,
            hint: 'Contact support to change your mobile number',
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Security'),
          _tile(
            context,
            Icons.lock_outline,
            'Change Password',
            subtitle: 'Requires your current password',
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const _ChangePasswordDialog(),
            ),
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

  /// A row with an optional [hint] line. When [onTap] is null the row is
  /// read-only: no chevron and no tap affordance.
  Widget _tile(
    BuildContext context,
    IconData icon,
    String title, {
    String? subtitle,
    String? hint,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null && hint == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (hint != null)
                    Text(hint,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit single field dialog — owns its own controller lifecycle
// ---------------------------------------------------------------------------

class _EditFieldDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;
  final TextInputType keyboardType;

  /// Persists the value; resolves with the failure message, or null when
  /// the save really succeeded server-side.
  final Future<String?> Function(String value) save;

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
    if (value.isEmpty || _saving) return;
    setState(() => _saving = true);
    // Wait for the server outcome BEFORE dismissing, so the snack that
    // follows reflects what actually happened — no fake "saved".
    final error = await widget.save(value);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content:
          Text(error == null ? '${widget.title} — saved' : 'Not saved — $error'),
    ));
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

// ---------------------------------------------------------------------------
// Change password dialog — two-step (verify current → set new)
// ---------------------------------------------------------------------------

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  late final TextEditingController _current;
  late final TextEditingController _newPass;
  late final TextEditingController _confirm;

  bool _verified = false;
  bool _verifying = false;
  bool _saving = false;
  String? _verifyError;

  @override
  void initState() {
    super.initState();
    _current = TextEditingController();
    _newPass = TextEditingController();
    _confirm = TextEditingController();
  }

  @override
  void dispose() {
    _current.dispose();
    _newPass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_current.text.isEmpty) return;
    setState(() => _verifying = true);
    final ok = await context.read<VendorProvider>().verifyPassword(_current.text);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _verified = ok;
      _verifyError = ok ? null : 'Incorrect current password';
    });
  }

  Future<void> _savePassword() async {
    setState(() => _saving = true);
    final provider = context.read<VendorProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.changePassword(
      currentPassword: _current.text,
      newPassword: _newPass.text,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Password updated'
          : (provider.lastAuthError ?? 'Could not update password')),
    ));
  }

  bool get _canSave => _newPass.text.length >= 8 && _newPass.text == _confirm.text;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_verified) ...[
              TextField(
                controller: _current,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Current password'),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _verify(),
              ),
              if (_verifyError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_verifyError!,
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
                controller: _newPass,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'New password (min. 8 characters)'),
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm new password'),
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (_canSave) _savePassword();
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_verifying || _saving)
              ? null
              : !_verified
                  ? _verify
                  : _canSave
                      ? _savePassword
                      : null,
          child: Text(_verifying
              ? 'Verifying…'
              : _saving
                  ? 'Saving…'
                  : _verified
                      ? 'Save New Password'
                      : 'Verify'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section label widget
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              fontSize: 13)),
    );
  }
}
