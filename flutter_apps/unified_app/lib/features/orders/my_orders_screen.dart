import 'package:flutter/material.dart';
import '../../services/shop_service.dart';
import '../../models/order.dart';
import 'order_details_screen.dart';
import '../invoices/dealer_invoices_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const MyOrdersScreen({super.key, this.onBack});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final _shopService = ShopService();
  List<Order> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await _shopService.getOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _handleBack,
        ),
        title: const Text('My Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'My Invoices',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DealerInvoicesScreen())),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _orders.isEmpty
                  ? const Center(child: Text('No orders found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final o = _orders[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(o.orderNumber,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                'Status: ${o.status}\nTotal Weight: ${o.totalQuantityKg.toStringAsFixed(o.totalQuantityKg.truncateToDouble() == o.totalQuantityKg ? 0 : 2)} kg\nAssigned: ${o.assignedExecutiveName ?? 'Not Assigned'}'),
                            trailing:
                                const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          OrderDetailsScreen(order: o)));
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
