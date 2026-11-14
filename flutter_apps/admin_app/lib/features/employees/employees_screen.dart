import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/employee_model.dart';
import '../../providers/admin_provider.dart';
import 'employee_profile_screen.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchEmployees();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEmployeeDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final usernameController = TextEditingController();
    final codeController = TextEditingController(text: 'EMP-${DateTime.now().millisecondsSinceEpoch % 10000}');
    final territoryController = TextEditingController();
    final designationController = TextEditingController(text: 'Field Executive');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Field Executive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full Name *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone (10 Digits) *',
                      prefixText: '+91 ',
                      hintText: '9848011223',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final digits = v.replaceAll(RegExp(r'\D'), '');
                      final clean = (digits.startsWith('91') && digits.length == 12) ? digits.substring(2) : digits;
                      if (clean.length != 10) return '10-digit mobile number required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(labelText: 'Login Username *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: codeController,
                    decoration: const InputDecoration(labelText: 'Employee Code *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: territoryController,
                    decoration: const InputDecoration(labelText: 'Assigned Territory *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: designationController,
                    decoration: const InputDecoration(labelText: 'Designation'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);

                      final rawPhone = phoneController.text.replaceAll(RegExp(r'\D'), '');
                      final cleanPhone = (rawPhone.startsWith('91') && rawPhone.length == 12)
                          ? rawPhone.substring(2)
                          : rawPhone;

                      final payload = {
                        'full_name': nameController.text.trim(),
                        'phone': cleanPhone,
                        'username': usernameController.text.trim(),
                        'employee_code': codeController.text.trim(),
                        'assigned_territory': territoryController.text.trim(),
                        'designation': designationController.text.trim(),
                      };

                      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final errorMessage = await adminProvider.createEmployee(payload);

                      if (errorMessage == null) {
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Field Executive added successfully'),
                              backgroundColor: AppTheme.primaryLight,
                            ),
                          );
                        }
                      } else {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(errorMessage),
                              backgroundColor: Colors.redAccent,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Add Executive'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(EmployeeModel emp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Field Officer'),
        content: Text('Are you sure you want to remove "${emp.fullName}" (${emp.employeeCode})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final adminProvider = Provider.of<AdminProvider>(context, listen: false);
              final success = await adminProvider.deleteEmployee(emp.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Officer removed' : 'Failed to remove officer'),
                    backgroundColor: success ? AppTheme.primaryLight : Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _openEmployeeProfile(EmployeeModel emp) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeProfileScreen(
          employeeId: emp.id,
          initialEmployee: emp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);

    final filteredEmployees = adminProvider.employees.where((e) {
      return _searchQuery.isEmpty ||
          e.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.employeeCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.assignedTerritory.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.phone.contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Executive', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddEmployeeDialog,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search executive by name, code or territory...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => adminProvider.fetchEmployees(),
              color: AppTheme.primaryGreen,
              child: adminProvider.isLoadingEmployees && adminProvider.employees.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                  : filteredEmployees.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 54, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text('No field executives found', style: TextStyle(color: AppTheme.textMuted)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          itemCount: filteredEmployees.length,
                          itemBuilder: (ctx, i) {
                            final emp = filteredEmployees[i];
                            final isPresent = emp.attendanceStatus.toLowerCase() == 'present';

                            return Card(
                              key: ValueKey('fe_card_${emp.id}'),
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                key: ValueKey('fe_tap_${emp.id}'),
                                onTap: () => _openEmployeeProfile(emp),
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: isPresent ? Colors.green.shade100 : Colors.grey.shade200,
                                                child: Text(
                                                  emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'E',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isPresent ? AppTheme.primaryGreen : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    emp.fullName,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                  ),
                                                  Text(
                                                    '${emp.employeeCode} • ${emp.designation}',
                                                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                            tooltip: 'Remove',
                                            onPressed: () => _confirmDelete(emp),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textMuted),
                                          const SizedBox(width: 4),
                                          Text('Territory: ${emp.assignedTerritory}', style: const TextStyle(fontSize: 13)),
                                          const Spacer(),
                                          const Icon(Icons.phone_outlined, size: 16, color: AppTheme.textMuted),
                                          const SizedBox(width: 4),
                                          Text(emp.phone, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                      const Divider(height: 18),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${emp.distanceCoveredKm.toStringAsFixed(1)} KM Covered',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              emp.attendanceStatus,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isPresent ? Colors.green.shade800 : Colors.red.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
