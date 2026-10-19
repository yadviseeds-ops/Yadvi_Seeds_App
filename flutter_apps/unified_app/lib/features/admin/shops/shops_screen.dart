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
          title: Text('Assign Executive to ${shop.shopName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select a field sales officer to manage this dealer:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: selectedExecutiveId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Assigned Executive'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Unassigned'),
                  ),
                  ...adminProvider.employees.map((emp) => DropdownMenuItem<int?>(
                        value: emp.id,
                        child: Text('${emp.fullName} (${emp.assignedTerritory})'),
                      )),
                ],
                onChanged: (val) {
                  setDialogState(() => selectedExecutiveId = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await adminProvider.assignShop(shop.id, selectedExecutiveId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Officer assigned successfully' : 'Failed to assign officer'),
                      backgroundColor: success ? AppTheme.primaryLight : Colors.redAccent,
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
    final usernameController = TextEditingController();
    final locationController = TextEditingController();
    final addressController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Register Dealer / Shop', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: shopNameController,
                    decoration: const InputDecoration(labelText: 'Shop / Business Name *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: ownerNameController,
                    decoration: const InputDecoration(labelText: 'Owner Full Name *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Phone (10 Digits) *',
                      prefixText: '+91 ',
                      counterText: '',
                    ),
                    validator: (v) => (v == null || v.trim().length != 10) ? '10 digits required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(labelText: 'Login Username *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Market / City Location *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Full Address *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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

                      final payload = {
                        'shop_name': shopNameController.text.trim(),
                        'owner_name': ownerNameController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'username': usernameController.text.trim(),
                        'market_location': locationController.text.trim(),
                        'address': addressController.text.trim(),
                      };

                      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final success = await adminProvider.createShop(payload);

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Dealer created successfully' : 'Failed to create dealer'),
                            backgroundColor: success ? AppTheme.primaryLight : Colors.redAccent,
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Register Dealer'),
            ),
          ],
        ),
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
          s.dealerCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.marketLocation.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.phone.contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: const Text('Register Dealer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                hintText: 'Search dealer by name, shop, code or city...',
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
              onRefresh: () => adminProvider.fetchShops(),
              color: AppTheme.primaryGreen,
              child: adminProvider.isLoadingShops && adminProvider.shops.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                  : filteredShops.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.store_mall_directory_outlined, size: 54, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text('No dealers found', style: TextStyle(color: AppTheme.textMuted)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          itemCount: filteredShops.length,
                          itemBuilder: (ctx, i) {
                            final shop = filteredShops[i];

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            shop.shopName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.blue.shade200),
                                          ),
                                          child: Text(
                                            shop.dealerCode,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 16, color: AppTheme.textMuted),
                                        const SizedBox(width: 4),
                                        Text('Owner: ${shop.ownerName}', style: const TextStyle(fontSize: 13)),
                                        const Spacer(),
                                        const Icon(Icons.phone_outlined, size: 16, color: AppTheme.textMuted),
                                        const SizedBox(width: 4),
                                        Text(shop.phone, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textMuted),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${shop.marketLocation} • ${shop.address}',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 18),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          shop.assignedExecutiveName != null
                                              ? 'Officer: ${shop.assignedExecutiveName}'
                                              : 'Officer: Unassigned',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: shop.assignedExecutiveName != null
                                                ? AppTheme.primaryLight
                                                : Colors.orange.shade800,
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.person_pin, size: 16),
                                          label: const Text('Assign', style: TextStyle(fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                          ),
                                          onPressed: () => _showAssignDialog(shop),
                                        ),
                                      ],
                                    ),
                                  ],
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
