import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../models/order.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/local_storage.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late String _currentStatus;
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
    _connectWebSocket();
  }

  Future<void> _connectWebSocket() async {
    try {
      final token = await LocalStorage.getToken();
      if (token == null) return;
      
      final wsUrl = Uri.parse('${AppConfig.wsBaseUrl}/api/v1/ws/live-tracking?token=$token');
      _channel = WebSocketChannel.connect(wsUrl);
      
      _channel!.stream.listen((message) {
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'DELIVERY_STATUS_CHANGED') {
            final payload = data['data'];
            if (payload['lr_number'] == widget.order.lrNumber || payload['order_id'].toString() == widget.order.id.toString()) {
              setState(() {
                _currentStatus = payload['status'];
              });
            }
          }
        } catch (e) {
          debugPrint('WS Parse Error: $e');
        }
      });
    } catch (e) {
      debugPrint('WS Connection Error: $e');
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.order.orderNumber)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('ORDER INFORMATION', [
              _buildRow('Order Number', widget.order.orderNumber),
              _buildRow('Date', widget.order.createdAt.substring(0, 10)),
              _buildRow('Status', _currentStatus),
            ]),
            const SizedBox(height: 16),
            _buildSection('SHOP INFORMATION', [
              _buildRow('Shop Name', widget.order.shopName),
              _buildRow('Location', widget.order.shopLocation),
              _buildRow('Delivery Address', widget.order.deliveryAddress),
            ]),
            const SizedBox(height: 16),
            _buildSection('ASSIGNMENT', [
              _buildRow('Field Executive',
                  widget.order.assignedExecutiveName ?? 'Not Assigned'),
            ]),
            _buildShipmentDetailsCard(widget.order.lrNumber, _currentStatus),
            const SizedBox(height: 16),
            const Text('ITEMS',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green)),
            const Divider(),
            ...widget.order.items
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

  String _mapStatusDisplay(String backendStatus) {
    final status = backendStatus.toLowerCase();
    if (status == 'dispatched' || status == 'in_transit' || status == 'in transit') return 'In Transit';
    if (status == 'delivered') return 'Delivered';
    if (status == 'pending' || status == 'new') return 'Pending';
    if (status == 'cancelled') return 'Cancelled';
    return backendStatus;
  }

  String _getStatusSubtitle(String displayStatus) {
    switch (displayStatus) {
      case 'In Transit': return 'Your shipment is on its way.';
      case 'Delivered': return 'Your shipment has been delivered.';
      case 'Pending': return 'Your shipment is pending processing.';
      case 'Cancelled': return 'Your shipment was cancelled.';
      default: return 'Status update available.';
    }
  }

  IconData _getStatusIcon(String displayStatus) {
    switch (displayStatus) {
      case 'In Transit': return Icons.local_shipping_outlined;
      case 'Delivered': return Icons.check_circle_outline;
      case 'Pending': return Icons.hourglass_empty;
      case 'Cancelled': return Icons.cancel_outlined;
      default: return Icons.info_outline;
    }
  }

  Widget _buildShipmentDetailsCard(String? lrNumber, String backendStatus) {
    if (lrNumber == null || lrNumber.isEmpty) return const SizedBox.shrink();

    final displayStatus = _mapStatusDisplay(backendStatus);
    final subtitle = _getStatusSubtitle(displayStatus);
    final icon = _getStatusIcon(displayStatus);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text(
                'Shipment Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'serif',
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'LR ID',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          Text(
            lrNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Shipment Status',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.blue[300], size: 24),
                    const SizedBox(width: 12),
                    Text(
                      displayStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
