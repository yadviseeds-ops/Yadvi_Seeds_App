import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/auth_service.dart';
import '../../../providers/auth_provider.dart';
import '../../auth/unified_role_selection_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? initialProfile;

  const AdminProfileScreen({super.key, this.initialProfile});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  String? _errorMessage;

  Map<String, dynamic>? _profileData;

  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();

    if (widget.initialProfile != null) {
      _profileData = widget.initialProfile;
      _populateFields(widget.initialProfile!);
      _isLoading = false;
    } else {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _authService.getProfile();
      if (!mounted) return;

      setState(() {
        _profileData = profile;
        _populateFields(profile);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _populateFields(Map<String, dynamic> data) {
    _nameController.text = data['full_name'] ?? '';
    _usernameController.text = data['username'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _emailController.text = data['email'] ?? '';
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      if (_profileData != null) {
        _populateFields(_profileData!);
      }
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newName = _nameController.text.trim();
    final newUsername = _usernameController.text.trim();
    final newEmail = _emailController.text.trim();
    final newPhone = _phoneController.text.trim();

    final currentPhone = _profileData?['phone']?.toString().trim() ?? '';
    final phoneChanged = newPhone.isNotEmpty && newPhone != currentPhone;

    if (phoneChanged) {
      // Phone change requires Firebase SMS OTP verification
      final verified = await _promptPhoneVerification(newPhone);
      if (!verified) return;
    } else {
      await _executeProfileUpdate(
        fullName: newName,
        username: newUsername,
        email: newEmail,
      );
    }
  }

  Future<bool> _promptPhoneVerification(String newPhone) async {
    PhoneChangeVerificationSession? session;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sending verification code to new mobile number...'),
          duration: Duration(seconds: 2),
        ),
      );

      session = await _authService.requestPhoneChangeOtp(newPhone);
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send verification code: ${AuthService.formatAuthError(e)}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return false;
    }

    if (!mounted) return false;

    // 1. If instant auto-verification succeeded, proceed directly with ID token
    if (session.isAutoVerified) {
      await _executeProfileUpdate(
        fullName: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        newPhone: newPhone,
        firebaseIdToken: session.autoVerifiedToken,
      );
      return true;
    }

    // 2. Otherwise ensure verificationId exists for manual OTP verification
    final verificationId = session.verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to initialize verification session. Please try again.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return false;
    }

    // Show manual OTP input dialog
    final otpController = TextEditingController();
    bool isVerifying = false;
    String? dialogError;

    final token = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.security, color: AppTheme.primaryGreen),
                SizedBox(width: 8),
                Text('Verify Mobile Number', style: TextStyle(fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the 6-digit OTP sent to +91 $newPhone:',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '6-Digit OTP',
                    hintText: '123456',
                    errorText: dialogError,
                  ),
                ),
                if (isVerifying)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isVerifying ? null : () => Navigator.pop(ctx, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isVerifying
                    ? null
                    : () async {
                        final code = otpController.text.trim();
                        if (code.length != 6) {
                          setDialogState(() {
                            dialogError = 'Please enter a 6-digit code';
                          });
                          return;
                        }

                        setDialogState(() {
                          isVerifying = true;
                          dialogError = null;
                        });

                        try {
                          final idToken = await _authService.verifyPhoneChangeOtp(
                            verificationId,
                            code,
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx, idToken);
                          }
                        } catch (e) {
                          setDialogState(() {
                            isVerifying = false;
                            dialogError = 'Invalid code: ${AuthService.formatAuthError(e)}';
                          });
                        }
                      },
                child: const Text('Verify & Update'),
              ),
            ],
          );
        },
      ),
    );

    if (token != null && token.isNotEmpty) {
      await _executeProfileUpdate(
        fullName: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        newPhone: newPhone,
        firebaseIdToken: token,
      );
      return true;
    }
    return false;
  }

  Future<void> _executeProfileUpdate({
    required String fullName,
    String? username,
    String? email,
    String? newPhone,
    String? firebaseIdToken,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final updated = await _authService.updateProfile(
        fullName: fullName,
        username: username,
        email: email,
        newPhone: newPhone,
        firebaseIdToken: firebaseIdToken,
      );

      if (!mounted) return;

      // Update provider user name to keep drawer synchronized
      if (updated['full_name'] != null) {
        Provider.of<AuthProvider>(context, listen: false)
            .updateCurrentUser(updated['full_name']);
      }

      setState(() {
        _profileData = updated;
        _populateFields(updated);
        _isEditing = false;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to end your administrator session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const UnifiedRoleSelectionScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'AD';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Profile & Settings'),
        actions: [
          if (!_isLoading && _errorMessage == null)
            IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined),
              tooltip: _isEditing ? 'Cancel Editing' : 'Edit Profile',
              onPressed: _isSaving
                  ? null
                  : () {
                      if (_isEditing) {
                        _cancelEdit();
                      } else {
                        setState(() {
                          _isEditing = true;
                        });
                      }
                    },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryGreen),
            SizedBox(height: 16),
            Text('Loading administrator profile...', style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: AppTheme.textDark),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final fullName = _profileData?['full_name'] ?? 'Administrator';
    final role = _profileData?['role'] ?? 'administrator';
    final isActive = _profileData?['is_active'] ?? true;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Avatar Header
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: AppTheme.primaryGreen,
                          child: Text(
                            _getInitials(fullName),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.verified_user,
                          size: 20,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.shield_outlined, size: 16, color: AppTheme.primaryGreen),
                        label: Text(
                          role == 'administrator' ? 'System Administrator' : role.toString().toUpperCase(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                        ),
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.08),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        avatar: Icon(
                          isActive ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: isActive ? Colors.teal : Colors.red,
                        ),
                        label: Text(
                          isActive ? 'Active Account' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive ? Colors.teal : Colors.red,
                          ),
                        ),
                        backgroundColor: (isActive ? Colors.teal : Colors.red).withValues(alpha: 0.08),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile Information Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Account Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        if (_isEditing)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentAmber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Editing Mode',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentAmber,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Full Name Field
                    _buildField(
                      label: 'Full Name',
                      controller: _nameController,
                      icon: Icons.person_outline,
                      isEditing: _isEditing,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Full name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Username Field
                    _buildField(
                      label: 'Admin Username',
                      controller: _usernameController,
                      icon: Icons.alternate_email,
                      isEditing: _isEditing,
                      helperText: _isEditing ? 'Required for login. Must be unique.' : null,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Username is required';
                        }
                        if (v.trim().length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Registered Mobile Field
                    _buildField(
                      label: 'Registered Mobile Number',
                      controller: _phoneController,
                      icon: Icons.phone_outlined,
                      isEditing: _isEditing,
                      keyboardType: TextInputType.phone,
                      helperText: _isEditing ? 'Changing number requires SMS OTP verification.' : null,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Mobile number is required';
                        }
                        final digits = v.trim().replaceAll(RegExp(r'\D'), '');
                        if (digits.length != 10) {
                          return 'Enter a valid 10-digit mobile number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email Address Field
                    _buildField(
                      label: 'Email Address',
                      controller: _emailController,
                      icon: Icons.mail_outline,
                      isEditing: _isEditing,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty) {
                          final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                          if (!emailRegex.hasMatch(v.trim())) {
                            return 'Enter a valid email address';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Edit / Save Actions
            if (_isEditing) ...[
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveProfile,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(_isSaving ? 'Saving Changes...' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _cancelEdit,
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                  });
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Account & Security Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: AppTheme.primaryGreen),
                    title: const Text('Authentication Mode'),
                    subtitle: const Text('Firebase Phone OTP Authentication'),
                    trailing: const Icon(Icons.shield_outlined, color: Colors.teal),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    subtitle: const Text('End your current administrator session'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red),
                    onTap: _confirmSignOut,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isEditing,
    String? helperText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    if (!isEditing) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppTheme.primaryGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  controller.text.isEmpty ? '—' : controller.text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 2,
        prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
