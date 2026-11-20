import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/core/theme/app_theme.dart';
import 'package:unified_app/models/shop_model.dart';
import 'package:unified_app/providers/admin_provider.dart';

class ShopsScreen extends StatefulWidget {
  const ShopsScreen({super.key});

  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      adminProvider.fetchShops();
      adminProvider.fetchEmployees();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAssignDialog(ShopModel shop) {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    int? selectedExecutiveId = shop.assignedExecutiveId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Assign Executive to ${shop.shopName}'),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            width: double.maxFinite,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Select a field sales officer to manage this dealer:',
                    style: TextStyle(fontSize: 14, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedExecutiveId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Executive',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Unassigned'),
                      ),
                      ...adminProvider.employees.map(
                        (emp) => DropdownMenuItem<int?>(
                          value: emp.id,
                          child: Text('${emp.fullName} (${emp.assignedTerritory})'),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setDialogState(() => selectedExecutiveId = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await adminProvider.assignShop(
                  shop.id,
                  selectedExecutiveId,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Officer assigned successfully'
                            : 'Failed to assign officer',
                      ),
                      backgroundColor: success
                          ? AppTheme.primaryLight
                          : Colors.redAccent,
                    ),
                  );
                }
              },
              child: const Text('Save Assignment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddShopDialog() {
    final formKey = GlobalKey<FormState>();
    final shopNameController = TextEditingController();
    final ownerNameController = TextEditingController();
    final phoneController = TextEditingController();
    final locationController = TextEditingController();
    final addressController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Register Dealer',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            width: double.maxFinite,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: shopNameController,
                      decoration: const InputDecoration(
                        labelText: 'Dealer / Business Name *',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: ownerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Proprietor / Full Name (Optional)',
                      ),
                      validator: null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: 'Phone (10 Digits) *',
                        prefixText: '+91 ',
                        counterText: '',
                      ),
                      validator: (v) => (v == null || v.trim().length != 10)
                          ? '10 digits required'
                          : null,
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Market / City Location *',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Full Address *',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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

                      final rawPhone = phoneController.text.replaceAll(
                        RegExp(r'\D'),
                        '',
                      );
                      final cleanPhone =
                          (rawPhone.startsWith('91') && rawPhone.length == 12)
                          ? rawPhone.substring(2)
                          : rawPhone;

                      final ownerName = ownerNameController.text.trim();
                      final payload = <String, dynamic>{
                        'shop_name': shopNameController.text.trim(),
                        if (ownerName.isNotEmpty) 'owner_name': ownerName,
                        'phone': cleanPhone,
                        'market_location': locationController.text.trim(),
                        'address': addressController.text.trim(),
                      };

                      final adminProvider = Provider.of<AdminProvider>(
                        context,
                        listen: false,
                      );
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final errorMessage = await adminProvider.createShop(
                        payload,
                      );

                      if (errorMessage == null) {
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Dealer registered successfully',
                              ),
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
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Register Dealer'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ShopModel shop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Dealer'),
        content: Text(
          'Are you sure you want to permanently delete dealer "${shop.shopName}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final adminProvider = Provider.of<AdminProvider>(context, listen: false);
              final errorMessage = await adminProvider.deleteShop(shop.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      errorMessage ?? 'Dealer permanently deleted',
                    ),
                    backgroundColor: errorMessage == null ? AppTheme.primaryLight : Colors.redAccent,
                    duration: Duration(seconds: errorMessage == null ? 3 : 5),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);

    final filteredShops = adminProvider.shops.where((s) {
      return _searchQuery.isEmpty ||
          s.shopName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.ownerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.marketLocation.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.phone.contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: const Text(
          'Register Dealer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: _showAddShopDialog,
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
                hintText: 'Search dealers by name, city, phone...',
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => adminProvider.fetchShops(),
              color: AppTheme.primaryGreen,
              child: adminProvider.isLoadingShops && adminProvider.shops.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  : filteredShops.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.store_mall_directory_outlined,
                            size: 54,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No dealers found',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 80),
                      itemCount: filteredShops.length,
                      itemBuilder: (ctx, i) {
                        final shop = filteredShops[i];

                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _showShopDetailsDialog(shop),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          shop.shopName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person_outline,
                                      size: 16,
                                      color: AppTheme.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      shop.ownerName.isNotEmpty
                                          ? 'Owner: ${shop.ownerName}'
                                          : 'Owner: (Not specified)',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.phone_outlined,
                                      size: 16,
                                      color: AppTheme.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      shop.phone,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: AppTheme.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${shop.marketLocation} • ${shop.address}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                // Financial Details Summary Strip
                                Container(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Debt Taken', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                            Text(
                                              ShopModel.formatCurrency(shop.debtTaken),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Debt Repaid', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                            Text(
                                              ShopModel.formatCurrency(shop.debtRepaid),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Total Balance', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                                            Text(
                                              ShopModel.formatCurrency(shop.totalBalance),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: shop.totalBalance >= 0 ? AppTheme.primaryGreen : Colors.red.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 14),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        shop.assignedExecutiveName != null
                                            ? 'Officer: ${shop.assignedExecutiveName}'
                                            : 'Officer: Unassigned',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              shop.assignedExecutiveName != null
                                              ? AppTheme.primaryLight
                                              : Colors.orange.shade800,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: AppTheme.primaryGreen,
                                        size: 20,
                                      ),
                                      tooltip: 'Edit Dealer',
                                      onPressed: () => _showEditShopDialog(shop),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      tooltip: 'Delete Dealer',
                                      onPressed: () => _confirmDelete(shop),
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.account_balance_wallet_outlined,
                                        size: 15,
                                        color: AppTheme.primaryGreen,
                                      ),
                                      label: const Text(
                                        'Financials',
                                        style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                      onPressed: () => _showFinancialDetailsDialog(shop),
                                    ),
                                    const SizedBox(width: 4),
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.person_pin,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Assign',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                      ),
                                      onPressed: () => _showAssignDialog(shop),
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

    void _showFinancialDetailsDialog(ShopModel shop) {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    final debtTakenCtrl = TextEditingController(
      text: shop.debtTaken != 0.0 ? shop.debtTaken.toStringAsFixed(2) : '0.00',
    );
    final debtRepaidCtrl = TextEditingController(
      text: shop.debtRepaid != 0.0 ? shop.debtRepaid.toStringAsFixed(2) : '0.00',
    );

    double calculateBalance(String takenStr, String repaidStr) {
      final taken = double.tryParse(takenStr.trim().replaceAll(',', '')) ?? 0.0;
      final repaid = double.tryParse(repaidStr.trim().replaceAll(',', '')) ?? 0.0;
      return double.parse((taken - repaid).toStringAsFixed(2));
    }

    double currentBalance = calculateBalance(debtTakenCtrl.text, debtRepaidCtrl.text);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Financial Details: ${shop.shopName}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              width: double.maxFinite,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manage credit and debt balances for this dealer.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: debtTakenCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Debt Taken *',
                          prefixText: '₹ ',
                          prefixIcon: Icon(Icons.arrow_circle_down_rounded, color: Colors.orange),
                          border: OutlineInputBorder(),
                          helperText: 'Total credit/debt taken by dealer',
                        ),
                        onChanged: (_) {
                          setDialogState(() {
                            currentBalance = calculateBalance(debtTakenCtrl.text, debtRepaidCtrl.text);
                          });
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter debt taken amount';
                          final num = double.tryParse(v.trim().replaceAll(',', ''));
                          if (num == null) return 'Enter a valid numeric amount';
                          if (num < 0) return 'Amount cannot be negative';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: debtRepaidCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Debt Repaid *',
                          prefixText: '₹ ',
                          prefixIcon: Icon(Icons.arrow_circle_up_rounded, color: Colors.green),
                          border: OutlineInputBorder(),
                          helperText: 'Total amount repaid by dealer',
                        ),
                        onChanged: (_) {
                          setDialogState(() {
                            currentBalance = calculateBalance(debtTakenCtrl.text, debtRepaidCtrl.text);
                          });
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter debt repaid amount';
                          final num = double.tryParse(v.trim().replaceAll(',', ''));
                          if (num == null) return 'Enter a valid numeric amount';
                          if (num < 0) return 'Amount cannot be negative';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: currentBalance >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: currentBalance >= 0 ? Colors.green.shade300 : Colors.red.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Balance (Calculated):',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: const Text(
                                    'Read-Only',
                                    style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ShopModel.formatCurrency(currentBalance),
                              key: const ValueKey('admin_calculated_total_balance'),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: currentBalance >= 0 ? const Color(0xFF0D4A32) : Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Formula: Total Balance = Debt Taken − Debt Repaid',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
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

                        final taken = double.parse(debtTakenCtrl.text.trim().replaceAll(',', ''));
                        final repaid = double.parse(debtRepaidCtrl.text.trim().replaceAll(',', ''));

                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final error = await adminProvider.updateShopFinancials(
                          shop.id,
                          debtTaken: taken,
                          debtRepaid: repaid,
                        );

                        if (!mounted) return;
                        if (error != null) {
                          setDialogState(() => isSaving = false);
                          scaffoldMessenger.showSnackBar(
                            SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
                          );
                        } else {
                          if (ctx.mounted) Navigator.pop(ctx);
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Financial details updated successfully'),
                              backgroundColor: AppTheme.primaryGreen,
                            ),
                          );
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Financials', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showShopDetailsDialog(ShopModel shop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.storefront, color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Dealer Profile: ${shop.shopName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Personal & Store Details Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Store & Contact Details',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showEditShopDialog(shop);
                            },
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text('Edit Profile', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const Divider(height: 12),
                      _buildDetailRow('Owner Name:', shop.ownerName.isNotEmpty ? shop.ownerName : '(Not specified)'),
                      _buildDetailRow('Mobile Phone:', '+91 ${shop.phone}'),
                      _buildDetailRow('Username:', shop.username ?? '—'),
                      _buildDetailRow('Market Location:', shop.marketLocation),
                      _buildDetailRow('Address:', shop.address),
                      _buildDetailRow('Assigned Officer:', shop.assignedExecutiveName ?? 'Unassigned'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 2. Financial Details Section (Visually Separate)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.account_balance_wallet, size: 16, color: AppTheme.primaryGreen),
                              SizedBox(width: 6),
                              Text(
                                'Financial Details',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0D4A32)),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showFinancialDetailsDialog(shop);
                            },
                            icon: const Icon(Icons.edit, size: 13),
                            label: const Text('Edit Financials', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                      const Divider(height: 12),
                      _buildDetailRow('Debt Taken:', ShopModel.formatCurrency(shop.debtTaken)),
                      _buildDetailRow('Debt Repaid:', ShopModel.formatCurrency(shop.debtRepaid)),
                      const SizedBox(height: 4),
                      _buildDetailRow(
                        'Total Balance:',
                        ShopModel.formatCurrency(shop.totalBalance),
                        isBold: true,
                        valueColor: shop.totalBalance >= 0 ? const Color(0xFF0D4A32) : Colors.red.shade700,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Balance = Debt Taken − Debt Repaid',
                        style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: valueColor ?? AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

void _showEditShopDialog(ShopModel shop) {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    final ownerNameController = TextEditingController(text: shop.ownerName);
    final shopNameController = TextEditingController(text: shop.shopName);
    final phoneController = TextEditingController(text: shop.phone);
    final usernameController = TextEditingController(text: shop.username ?? '');
    final emailController = TextEditingController(text: shop.email ?? '');
    final addressController = TextEditingController(text: shop.address);
    final marketLocationController = TextEditingController(text: shop.marketLocation);
    int? selectedExecutiveId = shop.assignedExecutiveId;
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
              const Icon(Icons.store, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Edit Dealer: ${shop.shopName}',
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
                      controller: shopNameController,
                      decoration: const InputDecoration(
                        labelText: 'Dealer Name *',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Shop Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: ownerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Proprietor / Full Name (Optional)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone (10 digits) *',
                        prefixIcon: Icon(Icons.phone_outlined),
                        prefixText: '+91 ',
                      ),
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isEmpty) return 'Phone number is required';
                        final digits = val.replaceAll(RegExp(r'\\D'), '');
                        if (digits.length != 10) return 'Phone must be exactly 10 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username (Optional)',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
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
                      controller: marketLocationController,
                      decoration: const InputDecoration(
                        labelText: 'Market Location *',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Market Location is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: selectedExecutiveId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Executive',
                        prefixIcon: Icon(Icons.person_pin_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Unassigned'),
                        ),
                        ...adminProvider.employees.map(
                          (emp) => DropdownMenuItem<int?>(
                            value: emp.id,
                            child: Text('${emp.fullName} (${emp.assignedTerritory})'),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setDialogState(() => selectedExecutiveId = val);
                      },
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
                      final phoneDigits = phoneController.text.trim().replaceAll(RegExp(r'\\D'), '');
                      final payload = <String, dynamic>{
                        'shop_name': shopNameController.text.trim(),
                        'phone': phoneDigits,
                        'owner_name': ownerNameController.text.trim(),
                        'market_location': marketLocationController.text.trim(),
                        'address': addressController.text.trim(),
                        'assigned_executive_id': selectedExecutiveId,
                      };
                      if (usernameController.text.trim().isNotEmpty) {
                        payload['username'] = usernameController.text.trim();
                      }
                      if (emailController.text.trim().isNotEmpty) {
                        payload['email'] = emailController.text.trim();
                      }
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final error = await adminProvider.updateShop(shop.id, payload);
                      if (!mounted) return;
                      if (error != null) {
                        setDialogState(() => isSaving = false);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      } else {
                        if (ctx.mounted) Navigator.pop(ctx);
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Dealer updated successfully'),
                            backgroundColor: AppTheme.primaryGreen,
                          ),
                        );
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
