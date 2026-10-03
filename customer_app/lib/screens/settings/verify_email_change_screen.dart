import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

/// OTP confirmation for an email change. The demo code is shown on-screen
/// (the real backend emails it via Resend).
class VerifyEmailChangeScreen extends StatefulWidget {
  final String newEmail;
  final String demoOtp;
  const VerifyEmailChangeScreen({super.key, required this.newEmail, required this.demoOtp});

  @override
  State<VerifyEmailChangeScreen> createState() => _VerifyEmailChangeScreenState();
}

class _VerifyEmailChangeScreenState extends State<VerifyEmailChangeScreen> {
  final _otpController = TextEditingController();
  bool _loading = false;
  String? _error;
  int _attempts = 0;
  static const _maxAttempts = 5;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.confirmEmailChange(_otpController.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      setState(() {
        _attempts++;
        _error = _attempts >= _maxAttempts
            ? 'Too many attempts — start the change again.'
            : 'Incorrect code. ${_maxAttempts - _attempts} attempt(s) left.';
      });
      if (_attempts >= _maxAttempts) auth.cancelEmailChange();
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Email updated to ${widget.newEmail}')),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm New Email')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Almost done',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-digit code to confirm your new email (${widget.newEmail}).',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                // No backend email-change endpoint yet — the code is local
                // and shown here so the flow is completable.
                'Offline preview — code: ${widget.demoOtp} (saved on this device only)',
                style: const TextStyle(fontSize: 12, color: AppColors.info),
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 12, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••••',
                errorText: _error,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _otpController.text.trim().length == 6 && !_loading ? _verify : null,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Verify & Update Email'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
