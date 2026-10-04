import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/fe_service.dart';
import '../../../models/shipment_model.dart';

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

  int? _activeSessionId;
  int? _activeShipmentId;
  Timer? _trackingTimer;
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _loadShipments();
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
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

  Future<void> _startTracking(ShipmentModel shipment) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled. Please enable them.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied.')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied.')));
      return;
    }

    try {
      final sessionId = await _feService.startTracking(shipment.id);
      
      setState(() {
        _activeSessionId = sessionId;
        _activeShipmentId = shipment.id;
        _isTracking = true;
      });

      await _sendGpsLocation();

      _trackingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        _sendGpsLocation();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tracking started.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _sendGpsLocation() async {
    if (_activeSessionId == null) return;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable GPS.')));
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      debugPrint('Tracking GPS: lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}, speed=${position.speed}');
      
      await _feService.sendTrackingLocation(
        _activeSessionId!,
        position.latitude,
        position.longitude,
        position.accuracy,
        position.speed,
      );
    } catch (e) {
      debugPrint('Error sending location: $e');
    }
  }

  Future<void> _stopTracking() async {
    if (_activeSessionId == null) return;

    try {
      await _feService.stopTracking(_activeSessionId!);
      
      _trackingTimer?.cancel();
      _trackingTimer = null;
      
      setState(() {
        _activeSessionId = null;
        _activeShipmentId = null;
        _isTracking = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tracking stopped.'), backgroundColor: Colors.blue));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
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
                const SizedBox(height: 12),
                if (_isTracking && _activeShipmentId == s.id) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.gps_fixed, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text('Tracking Active', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _stopTracking,
                      icon: const Icon(Icons.stop),
                      label: const Text('STOP TRACKING'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    ),
                  )
                ] else if (!_isTracking) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _startTracking(s),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('START TRACKING'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    ),
                  )
                ]
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
