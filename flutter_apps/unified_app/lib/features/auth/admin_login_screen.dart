import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../admin/main_scaffold.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _otpFormKey = GlobalKey<FormState>();
  final _otpUsernameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isOtpSent = false;

  @override
  void dispose() {
    _otpUsernameController.dispose();
    _mobileController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.requestOtp(
        _otpUsernameController.text.trim(),
        _mobileController.text.trim(),
        expectedRole: 'administrator',
      );
      setState(() {
        _isOtpSent = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent to registered mobile.'),
            backgroundColor: AppTheme.primaryLight,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[AdminLoginScreen] _handleRequestOtp exception: $e\n$stackTrace');
      if (mounted) {
        final message = AuthService.formatAuthError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_otpController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit OTP'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final success = await authProvider.verifyOtp(
        _otpUsernameController.text.trim(),
        _mobileController.text.trim(),
        _otpController.text.trim(),
        expectedRole: 'administrator',
      );
      if (success && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdminMainScaffold()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Administrator Login'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/yhs_logo.png',
                    height: 240,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'System Administration Console',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 14),

                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Form(
                        key: _otpFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _otpUsernameController,
                              enabled: !_isOtpSent,
                              decoration: const InputDecoration(
                                labelText: 'Admin Username',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _mobileController,
                              enabled: !_isOtpSent,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              decoration: const InputDecoration(
                                labelText: 'Registered Mobile Number',
                                prefixIcon: Icon(Icons.phone_outlined),
                                prefixText: '+91 ',
                                counterText: '',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Required';
                                if (v.trim().length != 10) return 'Must be 10 digits';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            if (_isOtpSent) ...[
                              TextFormField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  labelText: 'Enter 6-Digit SMS OTP',
                                  prefixIcon: Icon(Icons.lock_clock_outlined),
                                  counterText: '',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: authProvider.isLoading ? null : _handleRequestOtp,
                                    child: const Text('Resend Code'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],

                            const SizedBox(height: 8),

                            ElevatedButton(
                              onPressed: authProvider.isLoading
                                  ? null
                                  : (_isOtpSent ? _handleVerifyOtp : _handleRequestOtp),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      _isOtpSent ? 'Verify OTP & Enter Console' : 'Send Verification OTP',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

