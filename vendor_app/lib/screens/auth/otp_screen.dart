import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'create_password_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  int _secondsLeft = 300; // 5 minutes, matches spec
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 300);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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

  void _verify() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() => _error = 'Enter the full 6-digit code');
      return;
    }
    if (_secondsLeft == 0) {
      setState(() => _error = 'Code expired. Please resend.');
      return;
    }
    // TODO: POST /auth/verify-otp to the FastAPI backend
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreatePasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Your Account')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We sent a 6-digit code to ${widget.email}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Demo mode — use code 123456',
                style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
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
                  Text('Expires in $_formattedTime', style: const TextStyle(color: AppColors.textSecondary)),
                  TextButton(
                    onPressed: _secondsLeft == 0 ? _startTimer : null,
                    child: const Text('Resend Code'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _verify, child: const Text('Verify')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: _controllers[index],
        focusNode: _nodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(counterText: ''),
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