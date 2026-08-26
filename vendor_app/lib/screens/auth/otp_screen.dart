import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/vendor_provider.dart';
import '../../theme/app_theme.dart';
import 'create_password_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  int _secondsLeft = 300; // 5 minutes, matches the backend's OTP expiry
  Timer? _timer;
  String? _error;
  bool _loading = false;
  int _resendCooldown = 0;
  Timer? _resendCooldownTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 300);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _startResendCooldown() {
    _resendCooldownTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendCooldown <= 0) {
        t.cancel();
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resendCooldownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _formattedTime {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _verify() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() => _error = 'Enter the full 6-digit code');
      return;
    }
    if (_secondsLeft == 0) {
      setState(() => _error = 'Code expired. Please resend.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    final provider = context.read<VendorProvider>();
    final ok = await provider.verifyRegistrationOtp(code);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = ok ? null : (provider.lastAuthError ?? 'Incorrect code');
    });
    if (!ok) return;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreatePasswordScreen()),
    );
  }

  Future<void> _resend() async {
    final provider = context.read<VendorProvider>();
    await provider.resendRegistrationOtp();
    if (!mounted) return;
    setState(() {
      _error = provider.lastAuthError;
      _secondsLeft = 300;
    });
    if (_error != null) return;
    _startTimer();
    _startResendCooldown();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A new code has been sent to your email')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Your Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We sent a 6-digit code to ${widget.email}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _otpBox(i)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Expires in $_formattedTime',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  TextButton(
                    onPressed: (_secondsLeft == 0 && _resendCooldown == 0 && !_loading)
                        ? _resend
                        : null,
                    child: Text(_resendCooldown > 0
                        ? 'Resend in ${_resendCooldown}s'
                        : 'Resend Code'),
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
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
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

  Widget _otpBox(int index) {
    return SizedBox(
      width: 50,
      height: 64,
      child: TextField(
        controller: _controllers[index],
        focusNode: _nodes[index],
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.surfaceMuted,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _nodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _nodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}
