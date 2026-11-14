import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/auth/auth_service.dart';
import '../auth/role_selection_screen.dart';
import '../cart/cart_provider.dart';
import '../../core/network/api_client.dart';
import '../../core/config/app_config.dart';
import '../../services/shop_service.dart';

class ProfileTab extends StatefulWidget {
  final VoidCallback? onBack;

  const ProfileTab({super.key, this.onBack});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _shopData;
  final ApiClient _apiClient = ApiClient();
  final ShopService _shopService = ShopService();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await _apiClient.get('/api/v1/shops/my');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _shopData = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load profile. Error: ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Network error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showEditProfileDialog() {
    if (_shopData == null) return;
    final ownerNameCtrl = TextEditingController(text: _shopData!['owner_name'] ?? '');
    final shopNameCtrl = TextEditingController(text: _shopData!['shop_name'] ?? '');
    final emailCtrl = TextEditingController(text: _shopData!['email'] ?? '');
    final addressCtrl = TextEditingController(text: _shopData!['address'] ?? '');
    final marketLocationCtrl = TextEditingController(text: _shopData!['market_location'] ?? '');
    final phone = _shopData!['phone'] ?? '—';
    final username = (_shopData!['username'] != null && _shopData!['username'].toString().isNotEmpty)
        ? _shopData!['username'].toString()
        : 'Registered User';
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.edit, color: Color(0xFF0D4A32)),
                  SizedBox(width: 8),
                  Text('Edit Shop Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Read-only Phone (Admin-Assigned)
                      TextFormField(
                        initialValue: '+91 $phone',
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Mobile Number (Read-Only)',
                          helperText: 'This information is assigned and managed by Admin.',
                          prefixIcon: const Icon(Icons.phone, size: 20),
                          suffixIcon: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Read-only Username (Admin-Assigned)
                      TextFormField(
                        initialValue: username,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Username (Read-Only)',
                          helperText: 'This information is assigned and managed by Admin.',
                          prefixIcon: const Icon(Icons.account_circle, size: 20),
                          suffixIcon: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Owner Full Name (Optional per Task 6)
                      TextFormField(
                        controller: ownerNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Owner Full Name (Optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Shop Name (Mandatory)
                      TextFormField(
                        controller: shopNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Shop / Business Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Shop name is required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Email (Optional)
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address (Optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Market Location
                      TextFormField(
                        controller: marketLocationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Market / City Location',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Address (Mandatory)
                      TextFormField(
                        controller: addressCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Full Address *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D4A32),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          setDialogState(() => isSaving = true);
                          try {
                            await _shopService.updateProfile(
                              ownerName: ownerNameCtrl.text.trim(),
                              shopName: shopNameCtrl.text.trim(),
                              email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                              address: addressCtrl.text.trim(),
                              marketLocation: marketLocationCtrl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _fetchProfile();
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated successfully!'),
                                  backgroundColor: Color(0xFF0D4A32),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            String msg = e.toString().replaceFirst('Exception: ', '');
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                Provider.of<CartProvider>(context, listen: false).clearCart();
              } catch (_) {}
              await AuthService().logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _fetchProfile();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final data = _shopData!;
    final ownerName = (data['owner_name'] != null && data['owner_name'].toString().isNotEmpty)
        ? data['owner_name'].toString()
        : 'Registered Dealer';
    final shopName = data['shop_name'] ?? 'Unknown Shop';
    final phone = data['phone'] ?? 'N/A';
    final username = (data['username'] != null && data['username'].toString().isNotEmpty)
        ? data['username'].toString()
        : 'Registered User';
    final email = data['email'] ?? 'Not Provided';
    final address = data['address'] ?? 'Not Provided';
    final marketLocation = data['market_location'] ?? 'Unspecified';
    final officerName = data['assigned_executive_name'] ?? 'Not Assigned';
    final ownerPhotoUrl = data['owner_photo_url'];

    String initial = 'U';
    if (ownerName.isNotEmpty) {
      initial = ownerName[0].toUpperCase();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _handleBack,
        ),
        title: const Text('Profile', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF0D4A32)),
            tooltip: 'Edit Profile',
            onPressed: _showEditProfileDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.green.shade100,
                        backgroundImage: ownerPhotoUrl != null && ownerPhotoUrl.isNotEmpty
                            ? NetworkImage('${AppConfig.apiBaseUrl}$ownerPhotoUrl')
                            : null,
                        child: ownerPhotoUrl == null || ownerPhotoUrl.isEmpty
                            ? Text(
                                initial,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ownerName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              shopName,
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '+91 $phone',
                              style: const TextStyle(color: Colors.teal, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Username: $username',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showEditProfileDialog,
                      icon: const Icon(Icons.edit, size: 16, color: Color(0xFF0D4A32)),
                      label: const Text('Edit Profile Information', style: TextStyle(color: Color(0xFF0D4A32), fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0D4A32)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Business & Store Details Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Business & Store Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  _buildCredentialRow('Username:', username),
                  const SizedBox(height: 12),
                  _buildCredentialRow('Shop Name:', shopName),
                  const SizedBox(height: 12),
                  _buildCredentialRow('Email:', email),
                  const SizedBox(height: 12),
                  _buildCredentialRow('Market Location:', marketLocation),
                  const SizedBox(height: 12),
                  _buildCredentialRow('Address:', address),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Distributor Credentials Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Distributor Network',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCredentialRow('Assigned Field Officer:', officerName, valueColor: Colors.teal),
                  const SizedBox(height: 12),
                  _buildCredentialRow('Account Status:', data['status'] ?? 'Active', valueColor: Colors.green),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showLogoutDialog,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.red.shade50,
                  side: BorderSide(color: Colors.red.shade200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value, {Color valueColor = Colors.black87}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: valueColor),
          ),
        ),
      ],
    );
  }
}
