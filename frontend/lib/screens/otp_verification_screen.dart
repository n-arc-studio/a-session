import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String purpose; // 'verify' or 'reset'
  final VoidCallback onSuccess;

  const OtpVerificationScreen({
    Key? key,
    required this.email,
    required this.purpose,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String _errorMessage = '';
  int _secondsRemaining = 600; // 10分

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _secondsRemaining--;
        });
        if (_secondsRemaining > 0) {
          _startCountdown();
        }
      }
    });
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (widget.purpose == 'verify') {
        await _authService.verifyEmail(widget.email, _otpController.text);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メール認証に成功しました')),
        );
      } else if (widget.purpose == 'reset') {
        // パスワードリセット画面に遷移
        Navigator.of(context).pushReplacementNamed(
          '/reset-password',
          arguments: {
            'email': widget.email,
            'code': _otpController.text,
          },
        );
        return;
      }
      widget.onSuccess();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resendOtp() async {
    try {
      await _authService.sendVerificationOtp(widget.email);
      setState(() {
        _secondsRemaining = 600;
      });
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTPを再送信しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('再送信に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.purpose == 'verify' ? 'メール認証' : 'パスワードリセット'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.email,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Text(
              'メール認証コードを入力してください',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _otpController,
              decoration: InputDecoration(
                labelText: '認証コード (6桁)',
                hintText: '000000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 16),
            Text(
              '有効期限: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: _secondsRemaining < 60 ? Colors.red : Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('認証'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _resendOtp,
              child: const Text('コードを再送信'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }
}
