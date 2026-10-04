import 'package:flutter/material.dart';
import '../../models/order.dart';
import 'live_tracking_screen.dart';

class OrderDetailsScreen extends StatelessWidget {
  final Order order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(order.orderNumber)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('ORDER INFORMATION', [
              _buildRow('Order Number', order.orderNumber),
              _buildRow('Date', order.createdAt.substring(0, 10)),
              _buildRow('Status', order.status),
            ]),
            const SizedBox(height: 16),
            _buildSection('SHOP INFORMATION', [
              _buildRow('Shop Name', order.shopName),
              _buildRow('Location', order.shopLocation),
              _buildRow('Delivery Address', order.deliveryAddress),
            ]),
            const SizedBox(height: 16),
            _buildSection('ASSIGNMENT', [
              _buildRow('Field Executive',
                  order.assignedExecutiveName ?? 'Not Assigned'),
            ]),
            const SizedBox(height: 16),
            if (order.lrNumber != null)
              _buildSection('SHIPMENT', [
                _buildRow('LR Number', order.lrNumber ?? ''),
                _buildRow('Transporter', order.transporterName ?? ''),
              ]),
            if (order.lrNumber != null) const SizedBox(height: 16),
            if (order.lrNumber != null && order.status != 'Delivered' && order.status != 'Cancelled') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => LiveTrackingScreen(order: order)));
                  },
                  icon: const Icon(Icons.satellite_alt),
                  label: const Text('TRACK LIVE SHIPMENT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text('ITEMS',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green)),
            const Divider(),
            ...order.items
                .map((item) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(item.productName),
                        subtitle:
                            Text('SKU: ${item.sku}\nSize: ${item.packageSize}'),
                        trailing: Text('${item.quantityBags} Bags',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green)),
        const Divider(),
        ...children,
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              flex: 2,
              child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(
              flex: 3,
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
