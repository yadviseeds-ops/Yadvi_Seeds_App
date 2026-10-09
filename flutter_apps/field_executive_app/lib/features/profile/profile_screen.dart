import 'package:flutter/material.dart';
import '../../services/fe_service.dart';
import '../../models/fe_profile.dart';
import '../../core/auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../auth/role_selection_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _feService = FeService();
  final _authService = AuthService();
  FeProfile? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _feService.getMyProfile();
      setState(() {
        _profile = profile;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen()), (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0D4A32),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF0D4A32), Color(0xFF1A7A55)]),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 48),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _profile?.fullName ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF0D4A32)),
                      ),
                      Text(
                        _profile?.designation ?? '',
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 24),

                      // Info card
                      _buildInfoCard([
                        _buildInfoRow(Icons.badge, 'Employee ID', _profile?.employeeCode ?? '—'),
                        _buildInfoRow(Icons.person_outline, 'Username', 'Logged In'),
                        _buildInfoRow(Icons.phone, 'Mobile', _profile?.phone ?? '—'),
                        _buildInfoRow(Icons.email, 'Email', _profile?.email ?? '—'),
                        _buildInfoRow(Icons.map, 'Territory', _profile?.assignedTerritory ?? '—'),
                        _buildInfoRow(
                          Icons.circle,
                          'Status',
                          _profile?.isActive == true ? 'Active' : 'Inactive',
                          valueColor: _profile?.isActive == true ? Colors.green : Colors.red,
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // GPS status
                      _buildInfoCard([
                        _buildInfoRow(Icons.location_on, 'Last Lat', _profile?.currentLat?.toStringAsFixed(6) ?? 'Not set'),
                        _buildInfoRow(Icons.location_on, 'Last Lng', _profile?.currentLng?.toStringAsFixed(6) ?? 'Not set'),
                      ], title: 'Last Known Location'),
                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard(List<Widget> rows, {String? title}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D4A32), fontSize: 14)),
            const Divider(height: 16),
          ],
          ...rows,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0D4A32)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14))),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: valueColor ?? const Color(0xFF1A1A1A))),
        ],
      ),
    );
  }
}
