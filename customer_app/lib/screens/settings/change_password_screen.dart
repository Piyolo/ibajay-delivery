import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

/// Change Password with current-password verification:
/// Step 1 — current password is validated before anything else.
/// Step 2 — new password + confirmation (min 8 chars, must match).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _verifying = false;
  bool _saving = false;
  String? _currentError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _newPasswordValid => _newController.text.length >= 8;
  bool get _confirmValid => _confirmController.text == _newController.text;
  bool get _canSave => _newPasswordValid && _confirmValid;

  Future<void> _verifyCurrent() async {
    setState(() {
      _verifying = true;
      _currentError = null;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyPassword(_currentController.text);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      if (!ok) _currentError = 'Incorrect current password';
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    try {
      await auth.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update password. Please try again.')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Password updated')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Step 1 — Verify your identity',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Enter your current password to continue.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: _currentController,
              obscureText: _obscureCurrent,
              enabled: !_verifying,
              decoration: InputDecoration(
                labelText: 'Current password',
                errorText: _currentError,
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 20),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _currentController.text.isEmpty || _verifying ? null : _verifyCurrent,
                icon: _verifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.verified_user_outlined, size: 18),
                label: Text(_currentError != null
                    ? 'Try Again'
                    : _verifying
                        ? 'Verifying…'
                        : 'Verify Current Password'),
              ),
            ),
            const Divider(height: 40),
            const Text('Step 2 — Set a new password',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 16),
            TextField(
              controller: _newController,
              obscureText: _obscureNew,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'New password (min. 8 characters)',
                errorText: _newController.text.isEmpty || _newPasswordValid
                    ? null
                    : 'At least 8 characters',
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                errorText: _confirmController.text.isEmpty || _confirmValid
                    ? null
                    : 'Passwords do not match',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSave && !_saving ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Save New Password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
