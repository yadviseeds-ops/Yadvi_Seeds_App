import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../main_scaffold.dart';

class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form Controllers - OTP Tab
  final _otpFormKey = GlobalKey<FormState>();
  final _otpUsernameController = TextEditingController(text: 'ADMIN');
  final _mobileController = TextEditingController(text: '9529403798');
  final _otpController = TextEditingController();

  // Form Controllers - Password Tab
  final _passFormKey = GlobalKey<FormState>();
  final _passUsernameController = TextEditingController(text: 'ADMIN');
  final _passwordController = TextEditingController();

  bool _isOtpSent = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _otpUsernameController.dispose();
    _mobileController.dispose();
    _otpController.dispose();
    _passUsernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showServerSettingsDialog() {
    final serverController = TextEditingController(text: AppConfig.apiBaseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend Server URL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set the FastAPI backend URL (e.g. http://10.0.2.2:8000 for Android emulator or your LAN IP):',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: serverController,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'http://10.0.2.2:8000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await AppConfig.resetBaseUrl();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Reset Default'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (serverController.text.trim().isNotEmpty) {
                await AppConfig.setCustomBaseUrl(serverController.text.trim());
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRequestOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.requestOtp(
        _otpUsernameController.text.trim(),
        _mobileController.text.trim(),
      );
      setState(() {
        _isOtpSent = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent successfully to registered mobile.'),
            backgroundColor: AppTheme.primaryLight,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[UnifiedLoginScreen] _handleRequestOtp exception: $e\n$stackTrace');
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
      );
      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminMainScaffold()),
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

  Future<void> _handlePasswordLogin() async {
    if (!_passFormKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final success = await authProvider.loginWithPassword(
        _passUsernameController.text.trim(),
        _passwordController.text.trim(),
      );
      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminMainScaffold()),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.textMuted),
            tooltip: 'Server Settings',
            onPressed: _showServerSettingsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Brand Header
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 42,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'YADVI SEEDS',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Administrator Management Console',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tab selector (OTP vs Password)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: AppTheme.textMuted,
                      tabs: const [
                        Tab(text: 'Firebase Phone OTP'),
                        Tab(text: 'Password Fallback'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tab view content
                  SizedBox(
                    height: 380,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // TAB 1: Firebase Phone OTP
                        Form(
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
                              const SizedBox(height: 14),

                              if (_isOtpSent) ...[
                                TextFormField(
                                  controller: _otpController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  decoration: const InputDecoration(
                                    labelText: 'Enter 6-Digit SMS OTP',
                                    prefixIcon: Icon(Icons.lock_clock_outlined),
                                    counterText: '',
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _isOtpSent = false;
                                          _otpController.clear();
                                        });
                                      },
                                      child: const Text('Change Mobile'),
                                    ),
                                    TextButton(
                                      onPressed: authProvider.isLoading ? null : _handleRequestOtp,
                                      child: const Text('Resend Code'),
                                    ),
                                  ],
                                ),
                              ],

                              const Spacer(),

                              ElevatedButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : (_isOtpSent ? _handleVerifyOtp : _handleRequestOtp),
                                child: authProvider.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Text(
                                        _isOtpSent ? 'Verify OTP & Enter Console' : 'Send Verification OTP',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ],
                          ),
                        ),

                        // TAB 2: Password Fallback
                        Form(
                          key: _passFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _passUsernameController,
                                decoration: const InputDecoration(
                                  labelText: 'Admin Username or Phone',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Role is strictly validated server-side. Non-administrator credentials will be rejected.',
                                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: authProvider.isLoading ? null : _handlePasswordLogin,
                                child: authProvider.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text(
                                        'Login with Password',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Connected API: ${AppConfig.apiBaseUrl}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    textAlign: TextAlign.center,
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
