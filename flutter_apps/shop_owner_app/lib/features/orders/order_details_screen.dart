import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../models/order.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/local_storage.dart';
import '../../services/shop_service.dart';
import '../cart/cart_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late Order _currentOrder;
  bool _isLoading = false;
  WebSocketChannel? _channel;
  final ShopService _shopService = ShopService();

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _connectWebSocket();
    _refreshOrder();
  }

  Future<void> _refreshOrder() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final orders = await _shopService.getOrders();
      final updatedOrder = orders.firstWhere((o) => o.id == _currentOrder.id, orElse: () => _currentOrder);
      if (mounted) {
        setState(() {
          _currentOrder = updatedOrder;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
            if (payload['order_id'].toString() == _currentOrder.id.toString()) {
              _refreshOrder();
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

  int _getStatusStepIndex(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'delivered') return 4;
    if (s == 'dispatched' || s == 'in transit' || s == 'in_transit' || s == 'out for delivery') return 3;
    if (s == 'processing' || s == 'packaging' || s == 'packed') return 2;
    if (s == 'confirmed') return 1;
    return 0; // New or unknown statuses stay grey
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF083C28),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.eco, color: Colors.greenAccent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentOrder.shopName.isNotEmpty ? _currentOrder.shopName : 'Shop Details',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Tracking Details',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshOrder,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Consignment Live Status',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              
              // Order Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F422C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORDER #${_currentOrder.orderNumber}',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _currentOrder.shopName.isNotEmpty ? _currentOrder.shopName : 'My Shop',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Volume: ',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          '${_currentOrder.totalQuantityBags} Bags',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Timeline Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transit Milestones',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTimeline(),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // LR Card
              if (_currentOrder.lrNumber != null && _currentOrder.lrNumber!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, color: Colors.green.shade800, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Transport Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'LR Number',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentOrder.lrNumber!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (_currentOrder.transporterName != null) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Transporter Name',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentOrder.transporterName!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    final stepIndex = _getStatusStepIndex(_currentOrder.status);
    
    return Column(
      children: [
        _buildTimelineStep(
          title: 'Order Received & Confirmed',
          subtitle: 'Processed at Central Hub',
          stepNumber: 1,
          isCompleted: stepIndex >= 1,
          isLast: false,
        ),
        _buildTimelineStep(
          title: 'Packaging & Batch Tagging',
          subtitle: 'ISTA certified testing verified',
          stepNumber: 2,
          isCompleted: stepIndex >= 2,
          isLast: false,
        ),
        _buildTimelineStep(
          title: 'Transporter Dispatched (LR Issued)',
          subtitle: 'Awaiting transporter assignment',
          stepNumber: 3,
          isCompleted: stepIndex >= 3,
          isLast: false,
        ),
        _buildTimelineStep(
          title: 'Delivered to Dealer',
          subtitle: 'Direct shop handover',
          stepNumber: 4,
          isCompleted: stepIndex >= 4,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required int stepNumber,
    required bool isCompleted,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted ? const Color(0xFF00C853) : Colors.grey.shade200,
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Center(
                          child: Text(
                            '$stepNumber',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isCompleted ? Colors.green.shade200 : Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isCompleted ? Colors.black87 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
