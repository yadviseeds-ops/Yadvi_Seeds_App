import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import 'role_otp_screen.dart';

class RoleLoginScreen extends StatefulWidget {
  final String roleValue;
  final String roleTitle;

  const RoleLoginScreen({
    super.key,
    required this.roleValue,
    required this.roleTitle,
  });

  @override
  State<RoleLoginScreen> createState() => _RoleLoginScreenState();
}

class _RoleLoginScreenState extends State<RoleLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _mobileController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.requestOtp(
        _usernameController.text.trim(),
        _mobileController.text.trim(),
        expectedRole: widget.roleValue,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoleOtpScreen(
              username: _usernameController.text.trim(),
              mobile: _mobileController.text.trim(),
              authService: _authService,
              roleValue: widget.roleValue,
              roleTitle: widget.roleTitle,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[RoleLoginScreen] _requestOtp exception: $e\n$stackTrace');
      if (mounted) {
        final message = AuthService.formatAuthError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFE = widget.roleValue == 'field_executive';
    final accentColor = isFE ? Colors.orange.shade800 : Colors.teal.shade700;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text('${widget.roleTitle} Login'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/yhs_logo.png',
                        height: 240,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.roleTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter your registered username and mobile number to receive a verification OTP:',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Registered Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _mobileController,
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
                    const SizedBox(height: 24),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                      ),
                      onPressed: _isLoading ? null : _requestOtp,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Request SMS OTP',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
