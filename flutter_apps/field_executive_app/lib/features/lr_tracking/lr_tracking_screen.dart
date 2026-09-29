import 'package:flutter/material.dart';
import '../../services/fe_service.dart';
import '../../models/shipment_model.dart';

class LrTrackingScreen extends StatefulWidget {
  const LrTrackingScreen({super.key});

  @override
  State<LrTrackingScreen> createState() => _LrTrackingScreenState();
}

class _LrTrackingScreenState extends State<LrTrackingScreen> {
  final _feService = FeService();
  List<ShipmentModel> _shipments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadShipments();
  }

  Future<void> _loadShipments() async {
    try {
      final shipments = await _feService.getMyShipments();
      setState(() {
        _shipments = shipments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      appBar: AppBar(
        title: const Text('LR Tracking', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0D4A32),
        actions: [
          IconButton(
            onPressed: () { setState(() { _isLoading = true; _error = null; }); _loadShipments(); },
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 56, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: () { setState(() { _isLoading = true; _error = null; }); _loadShipments(); }, child: const Text('Retry')),
                    ],
                  ),
                ))
              : _shipments.isEmpty
                  ? const Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 56, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No shipments assigned to you yet.', style: TextStyle(color: Colors.grey)),
                      ],
                    ))
                  : RefreshIndicator(
                      onRefresh: _loadShipments,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _shipments.length,
                        itemBuilder: (_, i) => _buildShipmentCard(_shipments[i]),
                      ),
                    ),
    );
  }

  Widget _buildShipmentCard(ShipmentModel s) {
    final Color statusColor = s.status.toLowerCase().contains('deliver')
        ? Colors.green
        : s.status.toLowerCase().contains('transit')
            ? Colors.blue
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0D4A32), Color(0xFF1A7A55)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(s.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace')),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                  child: Text(s.status, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildRow('LR Number', s.lrNumber, Icons.pin, isBold: true),
                _buildRow('Transporter', s.transporterName, Icons.local_shipping),
                if (s.vehicleNumber != null) _buildRow('Vehicle', s.vehicleNumber!, Icons.directions_bus),
                if (s.driverName != null) _buildRow('Driver', s.driverName!, Icons.person),
                if (s.driverPhone != null) _buildRow('Driver Phone', s.driverPhone!, Icons.phone),
                _buildRow('Dispatch Date', s.dispatchDate.toLocal().toString().substring(0, 10), Icons.calendar_today),
                _buildRow('Est. Delivery', s.estimatedDelivery, Icons.event_available),
                _buildRow('Current Location', s.currentLocation, Icons.location_on),
                _buildRow('Shop', s.shopName, Icons.store),
                _buildRow('Total Bags', '${s.totalBags} Bags', Icons.inventory),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, IconData icon, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0D4A32)),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(child: Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 13))),
        ],
      ),
    );
  }
}
