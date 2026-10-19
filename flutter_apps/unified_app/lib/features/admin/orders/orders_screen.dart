import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/core/theme/app_theme.dart';
import 'package:unified_app/models/order_model.dart';
import 'package:unified_app/providers/admin_provider.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _selectedStatus = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  final List<String> _statusFilters = [
    'All',
    'New',
    'Confirmed',
    'Dispatched',
    'Delivered',
    'Cancelled'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchOrders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return Colors.orange.shade800;
      case 'confirmed':
        return Colors.blue.shade700;
      case 'dispatched':
      case 'in transit':
        return Colors.purple.shade700;
      case 'delivered':
        return AppTheme.primaryGreen;
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return AppTheme.textMuted;
    }
  }

  void _showOrderDetail(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OrderDetailSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);

    // Apply filtering
    final filteredOrders = adminProvider.orders.where((o) {
      final matchesStatus = _selectedStatus == 'All' ||
          o.status.toLowerCase() == _selectedStatus.toLowerCase();
      final matchesQuery = _searchQuery.isEmpty ||
          o.orderNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          o.shopName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          o.shopLocation.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesStatus && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Column(
        children: [
          // Search & Filter header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search order number, dealer, or city...',
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
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusFilters.map((st) {
                      final isSelected = _selectedStatus == st;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(st),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.primaryGreen : AppTheme.textMuted,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedStatus = st);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => adminProvider.fetchOrders(),
              color: AppTheme.primaryGreen,
              child: adminProvider.isLoadingOrders && adminProvider.orders.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                  : filteredOrders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 54, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text('No orders found', style: TextStyle(color: AppTheme.textMuted)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filteredOrders.length,
                          itemBuilder: (ctx, i) {
                            final ord = filteredOrders[i];
                            final statusColor = _getStatusColor(ord.status);

                            return Card(
                              child: InkWell(
                                onTap: () => _showOrderDetail(ord),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            ord.orderNumber,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppTheme.textDark,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              ord.status,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.storefront, size: 16, color: AppTheme.textMuted),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              ord.shopName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (ord.shopLocation.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textMuted),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                ord.shopLocation,
                                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const Divider(height: 18),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${ord.totalQuantityKg.toStringAsFixed(ord.totalQuantityKg.truncateToDouble() == ord.totalQuantityKg ? 0 : 2)} kg total (${ord.totalItemsCount} varieties)',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.primaryLight,
                                            ),
                                          ),
                                          const Text(
                                            'View Details →',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.primaryGreen,
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

class _OrderDetailSheet extends StatefulWidget {
  final OrderModel order;
  const _OrderDetailSheet({required this.order});

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  final _lrController = TextEditingController();
  final _transporterController = TextEditingController();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _lrController.text = widget.order.lrNumber ?? '';
    _transporterController.text = widget.order.transporterName ?? '';
  }

  @override
  void dispose() {
    _lrController.dispose();
    _transporterController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isUpdating = true);
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);

    final success = await adminProvider.updateOrderStatus(
      widget.order.id,
      status,
      lrNumber: _lrController.text.trim().isNotEmpty ? _lrController.text.trim() : null,
      transporter: _transporterController.text.trim().isNotEmpty ? _transporterController.text.trim() : null,
    );

    setState(() => _isUpdating = false);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Order status updated to $status' : 'Failed to update order status'),
          backgroundColor: success ? AppTheme.primaryLight : Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ord = widget.order;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ord.orderNumber,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  ord.status,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Dealer: ${ord.shopName}', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (ord.contactPhone.isNotEmpty) Text('Contact: ${ord.contactPhone}'),
            if (ord.deliveryAddress.isNotEmpty) Text('Address: ${ord.deliveryAddress}'),
            const Divider(height: 24),
            const Text('Ordered Items:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...ord.items.map((it) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(it.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('SKU: ${it.sku} | Pack: ${it.packageSize}'),
                  trailing: Text(
                    '${it.quantity.toStringAsFixed(it.quantity.truncateToDouble() == it.quantity ? 0 : 2)} ${it.unit}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                )),
            const Divider(height: 24),
            const Text('Dispatch & Logistics Info:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _transporterController,
              decoration: const InputDecoration(
                labelText: 'Transporter Name',
                hintText: 'e.g. VRL Logistics',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _lrController,
              decoration: const InputDecoration(
                labelText: 'LR / Tracking Number',
                hintText: 'e.g. LR-984214',
              ),
            ),
            const SizedBox(height: 20),
            const Text('Update Status:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_isUpdating)
              const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => _updateStatus('Confirmed'),
                    child: const Text('Confirm'),
                  ),
                  ElevatedButton(
                    onPressed: () => _updateStatus('Dispatched'),
                    child: const Text('Dispatch'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    onPressed: () => _updateStatus('Delivered'),
                    child: const Text('Delivered'),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => _updateStatus('Cancelled'),
                    child: const Text('Cancel Order'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
