import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/core/theme/app_theme.dart';
import 'package:unified_app/models/employee_model.dart';
import 'package:unified_app/providers/admin_provider.dart';

class EmployeeProfileScreen extends StatefulWidget {
  final int employeeId;
  final EmployeeModel? initialEmployee;

  const EmployeeProfileScreen({
    super.key,
    required this.employeeId,
    this.initialEmployee,
  });

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  EmployeeModel? _employee;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmployee != null) {
      _employee = widget.initialEmployee;
      _isLoading = false;
    }
    _loadEmployeeDetails();
  }

  Future<void> _loadEmployeeDetails() async {
    if (_employee == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      final emp = await adminProvider.fetchEmployeeDetails(widget.employeeId);
      if (mounted) {
        if (emp != null) {
          setState(() {
            _employee = emp;
            _isLoading = false;
            _errorMessage = null;
          });
        } else {
          setState(() {
            _isLoading = false;
            if (_employee == null) {
              _errorMessage = 'Field Executive with ID #${widget.employeeId} not found.';
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_employee == null) {
            _errorMessage = 'Unable to load profile: $e';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text(
          _employee != null ? _employee!.fullName : 'Field Executive Profile',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0.5,
        leading: IconButton(
          key: const ValueKey('fe_profile_back_button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_employee != null)
            IconButton(
              key: const ValueKey('fe_profile_edit_button'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Profile & Credentials',
              onPressed: () => _showEditEmployeeDialog(_employee!),
            ),
          IconButton(
            key: const ValueKey('fe_profile_refresh_button'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadEmployeeDetails,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _employee == null) {
      return const Center(
        child: CircularProgressIndicator(
          key: ValueKey('fe_profile_loading'),
          color: AppTheme.primaryGreen,
        ),
      );
    }

    if (_errorMessage != null && _employee == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 56, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppTheme.textDark),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadEmployeeDetails,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Try Again', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
              ),
            ],
          ),
        ),
      );
    }

    if (_employee == null) {
      return const Center(
        child: Text(
          'No profile data available.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
        ),
      );
    }

    final emp = _employee!;
    final isPresent = emp.attendanceStatus.toLowerCase() == 'present';

    return RefreshIndicator(
      onRefresh: _loadEmployeeDetails,
      color: AppTheme.primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Profile Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: isPresent ? Colors.green.shade100 : Colors.grey.shade200,
                      child: Text(
                        emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'E',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isPresent ? AppTheme.primaryGreen : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.fullName,
                            key: const ValueKey('fe_profile_name'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            emp.designation.isNotEmpty ? (emp.designation == 'Field Sales Officer' ? 'Field Executive' : emp.designation) : 'Field Executive',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isPresent ? Colors.green.shade200 : Colors.red.shade200,
                                  ),
                                ),
                                child: Text(
                                  emp.attendanceStatus,
                                  key: const ValueKey('fe_profile_attendance'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isPresent ? Colors.green.shade800 : Colors.red.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: emp.isActive ? Colors.blue.shade50 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: emp.isActive ? Colors.blue.shade200 : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  emp.isActive ? 'Active Account' : 'Inactive Account',
                                  key: const ValueKey('fe_profile_status'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: emp.isActive ? Colors.blue.shade800 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Visit Performance Summary Cards (Task 9)
            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
                              Text(
                                '${emp.completedVisits}',
                                key: const ValueKey('fe_profile_completed_visits'),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Completed Visits',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Verified & recorded',
                            style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Icon(Icons.pending_actions_outlined, color: Colors.orange, size: 24),
                              Text(
                                '${emp.pendingVisits}',
                                key: const ValueKey('fe_profile_pending_visits'),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Pending Visits',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Awaiting completion',
                            style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 3. Assigned Shops Section (Task 9)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.store_mall_directory_outlined, size: 20, color: AppTheme.primaryGreen),
                            SizedBox(width: 8),
                            Text(
                              'Assigned Dealers',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            'Total Assigned Dealers: ${emp.totalAssignedShops}',
                            key: const ValueKey('fe_profile_total_assigned_shops'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (emp.assignedShops.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.storefront_outlined, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text(
                                'No dealers currently assigned to this executive.',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: emp.assignedShops.length,
                        separatorBuilder: (context, index) => const Divider(height: 16),
                        itemBuilder: (ctx, i) {
                          final shop = emp.assignedShops[i];
                          final isActiveShop = shop.status.toLowerCase() == 'active';

                          return Container(
                            key: ValueKey('fe_assigned_shop_${shop.id}'),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            child: Text(
                                              '#${shop.id}',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              shop.shopName,
                                              key: ValueKey('fe_shop_name_${shop.id}'),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textDark,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isActiveShop ? Colors.green.shade50 : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isActiveShop ? Colors.green.shade200 : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        shop.status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isActiveShop ? Colors.green.shade800 : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (shop.marketLocation.isNotEmpty || shop.address.isNotEmpty)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 15, color: AppTheme.textMuted),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          shop.marketLocation.isNotEmpty
                                              ? (shop.address.isNotEmpty
                                                  ? '${shop.marketLocation} • ${shop.address}'
                                                  : shop.marketLocation)
                                              : shop.address,
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (shop.ownerName != null && shop.ownerName!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 15, color: AppTheme.textMuted),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Owner: ${shop.ownerName}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                                      ),
                                    ],
                                  ),
                                ],
                                if (shop.phone != null && shop.phone!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 15, color: AppTheme.textMuted),
                                      const SizedBox(width: 6),
                                      Text(
                                        shop.phone!,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 4. Employee Work & Assignment Details Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Employment & Assignment Details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Employee Code',
                      value: emp.employeeCode,
                      valueKey: 'fe_profile_code',
                    ),
                    if (emp.username.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        icon: Icons.account_circle_outlined,
                        label: 'Username',
                        value: emp.username,
                        valueKey: 'fe_profile_username',
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      icon: Icons.work_outline,
                      label: 'Designation',
                      value: emp.designation.isNotEmpty ? (emp.designation == 'Field Sales Officer' ? 'Field Executive' : emp.designation) : 'Field Executive',
                      valueKey: 'fe_profile_designation',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      icon: Icons.map_outlined,
                      label: 'Assigned Territory',
                      value: emp.assignedTerritory.isNotEmpty ? emp.assignedTerritory : 'Unassigned',
                      valueKey: 'fe_profile_territory',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      icon: Icons.directions_walk,
                      label: 'Distance Covered Today',
                      value: '${emp.distanceCoveredKm.toStringAsFixed(1)} KM Covered',
                      valueKey: 'fe_profile_distance',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 5. Contact Information Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Registered Phone',
                      value: emp.phone.isNotEmpty ? emp.phone : 'Not provided',
                      valueKey: 'fe_profile_phone',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email Address',
                      value: (emp.email != null && emp.email!.isNotEmpty) ? emp.email! : 'Not provided',
                      valueKey: 'fe_profile_email',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 6. Location & Telemetry Card (WITHOUT any battery indicator)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Location & Field Telemetry',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Last Recorded GPS',
                      value: (emp.currentLat != null && emp.currentLng != null)
                          ? '${emp.currentLat!.toStringAsFixed(5)}, ${emp.currentLng!.toStringAsFixed(5)}'
                          : 'No GPS fix recorded',
                      valueKey: 'fe_profile_gps',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      icon: Icons.access_time_outlined,
                      label: 'Last Location Update',
                      value: emp.lastLocationUpdate != null
                          ? '${emp.lastLocationUpdate!.toLocal().year}-${emp.lastLocationUpdate!.toLocal().month.toString().padLeft(2, '0')}-${emp.lastLocationUpdate!.toLocal().day.toString().padLeft(2, '0')} ${emp.lastLocationUpdate!.toLocal().hour.toString().padLeft(2, '0')}:${emp.lastLocationUpdate!.toLocal().minute.toString().padLeft(2, '0')}'
                          : 'Never updated',
                      valueKey: 'fe_profile_last_update',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required String valueKey,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                key: ValueKey(valueKey),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditEmployeeDialog(EmployeeModel emp) {
    final nameController = TextEditingController(text: emp.fullName);
    final phoneController = TextEditingController(text: emp.phone);
    final usernameController = TextEditingController(text: emp.username);
    final emailController = TextEditingController(text: emp.email ?? '');
    final codeController = TextEditingController(text: emp.employeeCode);
    final designationController = TextEditingController(text: emp.designation);
    final territoryController = TextEditingController(text: emp.assignedTerritory);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.edit, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Edit Executive: ${emp.fullName}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone (10 digits) *',
                        prefixIcon: Icon(Icons.phone),
                        prefixText: '+91 ',
                      ),
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isEmpty) return 'Phone number is required';
                        final digits = val.replaceAll(RegExp(r'\D'), '');
                        if (digits.length != 10) return 'Phone must be exactly 10 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username *',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Username is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (Optional)',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: codeController,
                      decoration: const InputDecoration(
                        labelText: 'Employee Code *',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Employee Code is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: designationController,
                      decoration: const InputDecoration(
                        labelText: 'Designation *',
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Designation is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: territoryController,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Territory *',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Territory is required' : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
                      final phoneDigits = phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
                      final payload = <String, dynamic>{
                        'full_name': nameController.text.trim(),
                        'phone': phoneDigits,
                        'username': usernameController.text.trim(),
                        'employee_code': codeController.text.trim(),
                        'designation': designationController.text.trim(),
                        'assigned_territory': territoryController.text.trim(),
                      };
                      if (emailController.text.trim().isNotEmpty) {
                        payload['email'] = emailController.text.trim();
                      }
                      final error = await adminProvider.updateEmployee(emp.id, payload);
                      if (!mounted) return;
                      if (error != null) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      } else {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Field Executive profile updated successfully'),
                            backgroundColor: AppTheme.primaryGreen,
                          ),
                        );
                        _loadEmployeeDetails();
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Changes', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
