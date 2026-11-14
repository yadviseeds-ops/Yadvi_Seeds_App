import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/storage/local_storage.dart';
import '../../core/theme/app_theme.dart';
import '../field_executive/dashboard/dashboard_screen.dart' as fe;
import '../dashboard/dashboard_screen.dart' as so;

class RoleOtpScreen extends StatefulWidget {
  final String username;
  final String mobile;
  final AuthService authService;
  final String roleValue;
  final String roleTitle;

  const RoleOtpScreen({
    super.key,
    required this.username,
    required this.mobile,
    required this.authService,
    required this.roleValue,
    required this.roleTitle,
  });

  @override
  State<RoleOtpScreen> createState() => _RoleOtpScreenState();
}

class _RoleOtpScreenState extends State<RoleOtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await widget.authService.verifyOtp(
        widget.username,
        widget.mobile,
        otp,
        expectedRole: widget.roleValue,
      );

      if (success && mounted) {
        final actualRole = await LocalStorage.getRole();
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) {
            if (actualRole == 'field_executive') {
              return const fe.DashboardScreen();
            } else if (actualRole == 'shop_owner') {
              return const so.DashboardScreen();
            }
            return Scaffold(
              appBar: AppBar(title: const Text('Access Denied')),
              body: const Center(child: Text('Unauthorized role detected.')),
            );
          }),
          (route) => false,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[RoleOtpScreen] _verifyOtp exception: $e\n$stackTrace');
      if (mounted) {
        final message = AuthService.formatAuthError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isResending = true);
    try {
      await widget.authService.requestOtp(
        widget.username,
        widget.mobile,
        expectedRole: widget.roleValue,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent successfully.'), backgroundColor: AppTheme.primaryLight),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[RoleOtpScreen] _resendOtp exception: $e\n$stackTrace');
      if (mounted) {
        final message = AuthService.formatAuthError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFE = widget.roleValue == 'field_executive';
    final accentColor = isFE ? Colors.orange.shade800 : Colors.teal.shade700;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text('${widget.roleTitle} Verification'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock_clock_outlined, size: 40, color: accentColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter Verification Code',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter the 6-digit code sent to +91 ${widget.mobile}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 28),

                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: '------',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isResending ? null : _resendOtp,
                        child: _isResending
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Resend Code'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                    onPressed: _isLoading ? null : _verifyOtp,
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Verify & Enter Module', style: TextStyle(fontWeight: FontWeight.bold)),
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
