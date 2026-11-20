import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../models/order.dart';
import '../../../core/network/api_client.dart';
import '../../../services/receipt_pdf_service.dart';
import '../../../core/theme/app_theme.dart';

class AdminInvoicesScreen extends StatefulWidget {
  const AdminInvoicesScreen({super.key});

  @override
  State<AdminInvoicesScreen> createState() => _AdminInvoicesScreenState();
}

class _AdminInvoicesScreenState extends State<AdminInvoicesScreen> {
  final ApiClient _apiClient = ApiClient();
  final ReceiptPdfService _receiptPdfService = ReceiptPdfService();

  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllInvoices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiClient.get('/api/v1/orders');
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        final orders = data.map((item) => Order.fromJson(item)).toList();
        if (mounted) {
          setState(() {
            _allOrders = orders;
            _applySearch(_searchController.text);
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load orders (HTTP ${res.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _applySearch(String query) {
    final clean = query.trim().toLowerCase();
    setState(() {
      if (clean.isEmpty) {
        _filteredOrders = List.from(_allOrders);
      } else {
        _filteredOrders = _allOrders.where((o) {
          final invNum = ReceiptPdfService.generateInvoiceNumber(o).toLowerCase();
          final ordNum = o.orderNumber.toLowerCase();
          final dealerName = o.shopName.toLowerCase();
          final owner = (o.ownerName ?? '').toLowerCase();
          final location = o.shopLocation.toLowerCase();
          return invNum.contains(clean) ||
              ordNum.contains(clean) ||
              dealerName.contains(clean) ||
              owner.contains(clean) ||
              location.contains(clean);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Dealer Invoices & Receipts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Invoices',
            onPressed: _loadAllInvoices,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchController,
              onChanged: _applySearch,
              decoration: InputDecoration(
                hintText: 'Search by Invoice No, Dealer, Order Ref, City...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _applySearch('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          // Total Counter Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Invoices: ${_filteredOrders.length}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
                Text(
                  'Across ${_allOrders.map((o) => o.shopName).toSet().length} Dealers',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Invoices List
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
                onPressed: _loadAllInvoices,
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text(
              'No Invoices Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Try a different search term.'
                  : 'Invoices will be listed here once dealers place orders.',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllInvoices,
      color: AppTheme.primaryGreen,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _filteredOrders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final order = _filteredOrders[index];
          final invoiceNumber = ReceiptPdfService.generateInvoiceNumber(order);
          final invoiceDate = ReceiptPdfService.formatDate(order.createdAt);
          final itemsCount = order.items.length;
          final totalKg = order.totalQuantityKg;

          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.receipt_long, color: Colors.green.shade800, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoiceNumber,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              order.shopName.isNotEmpty ? order.shopName : 'Dealer',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (order.ownerName != null && order.ownerName!.isNotEmpty && order.ownerName != order.shopName)
                              Text(
                                'Proprietor: ${order.ownerName}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              'Order: ${order.orderNumber} • Date: $invoiceDate',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          order.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(order.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$itemsCount items • ${totalKg.toStringAsFixed(totalKg % 1 == 0 ? 0 : 2)} kg',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: const Color(0xFF1B5E20),
                              side: const BorderSide(color: Color(0xFF1B5E20)),
                            ),
                            icon: const Icon(Icons.visibility, size: 15),
                            label: const Text('View'),
                            onPressed: () => _receiptPdfService.printReceipt(context, order),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: const Color(0xFF1B5E20),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.download, size: 15),
                            label: const Text('PDF'),
                            onPressed: () => _receiptPdfService.downloadOrShareReceipt(context, order),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green.shade800;
      case 'dispatched':
        return Colors.blue.shade800;
      case 'confirmed':
        return Colors.teal.shade800;
      case 'cancelled':
        return Colors.red.shade800;
      default:
        return Colors.orange.shade800;
    }
  }
}

