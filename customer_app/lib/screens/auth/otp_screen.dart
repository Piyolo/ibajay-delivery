import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'create_password_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final bool isPasswordReset;

  const OtpScreen({
    super.key,
    required this.email,
    this.isPasswordReset = false,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  bool _loading = false;
  String? _error;
  int _attempts = 0;
  static const int _maxAttempts = 5;

  int _secondsLeft = 300; // 5 minutes
  Timer? _countdownTimer;
  Timer? _resendCooldownTimer;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _secondsLeft = 300;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 0) {
        timer.cancel();
        setState(() {});
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  void _startResendCooldown() {
    _resendCooldownTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _resendCooldown--);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _resendCooldownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _verify() async {
    if (_otpController.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    if (_attempts >= _maxAttempts) {
      setState(() => _error = 'Maximum attempts exceeded. Please request a new code.');
      return;
    }
    if (_secondsLeft <= 0) {
      setState(() => _error = 'This code has expired. Please request a new one.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyOtp(_otpController.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);

    if (!ok) {
      setState(() {
        _attempts++;
        _error = auth.lastAuthError ?? 'Incorrect code. ${_maxAttempts - _attempts} attempt(s) left.';
      });
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CreatePasswordScreen(
        email: widget.email,
        isPasswordReset: widget.isPasswordReset,
        verifiedOtp: _otpController.text.trim(),
      ),
    ));
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    await auth.resendOtp();
    if (!mounted) return;
    setState(() {
      _attempts = 0;
      _error = auth.lastAuthError;
    });
    if (_error != null) return;
    _startCountdown();
    _startResendCooldown();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A new code has been sent to your email')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Your Email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isPasswordReset ? 'Step 2 of 4' : 'Step 2-3 of 4',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              const Text('Enter verification code', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to ${widget.email}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _secondsLeft > 0 ? 'Expires in $_formattedTime' : 'Code expired',
                    style: TextStyle(
                      fontSize: 12,
                      color: _secondsLeft > 0 ? AppColors.textSecondary : AppColors.danger,
                    ),
                  ),
                  TextButton(
                    onPressed: _resendCooldown > 0 ? null : _resend,
                    child: Text(_resendCooldown > 0 ? 'Resend in ${_resendCooldown}s' : 'Resend Code'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('Verify'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
