import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/shop_model.dart';
import '../../providers/admin_provider.dart';

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
              const Text('Select a field sales officer to manage this shop owner:'),
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
          title: const Text('Register Shop Owner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                    decoration: const InputDecoration(labelText: 'Owner Full Name (Optional)'),
                    validator: null,
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
                      final ownerName = ownerNameController.text.trim();
                      final payload = <String, dynamic>{
                        'shop_name': shopNameController.text.trim(),
                        if (ownerName.isNotEmpty) 'owner_name': ownerName,
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
                            content: Text(success ? 'Shop Owner registered successfully' : 'Failed to register shop owner'),
                            backgroundColor: success ? AppTheme.primaryLight : Colors.redAccent,
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Register Shop Owner'),
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
          s.marketLocation.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.phone.contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: const Text('Register Shop Owner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                hintText: 'Search shop owner by name, shop, code or city...',
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
                              const Text('No shop owners found', style: TextStyle(color: AppTheme.textMuted)),
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
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 16, color: AppTheme.textMuted),
                                        const SizedBox(width: 4),
                                        Text(shop.ownerName.isNotEmpty ? 'Owner: ${shop.ownerName}' : 'Owner: (Not specified)', style: const TextStyle(fontSize: 13)),
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
                  'Edit Shop: ${shop.shopName}',
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
                        labelText: 'Shop Name *',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Shop Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: ownerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Owner Full Name (Optional)',
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
                      final error = await adminProvider.updateShop(shop.id, payload);
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
                            content: Text('Shop Owner updated successfully'),
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
