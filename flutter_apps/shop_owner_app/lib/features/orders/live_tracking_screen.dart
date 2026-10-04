import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/local_storage.dart';
import '../../models/order.dart';

enum TrackingState {
  connecting,
  waitingForLocation,
  live,
  reconnecting,
  disconnected,
  trackingEnded
}

class LiveTrackingScreen extends StatefulWidget {
  final Order order;
  const LiveTrackingScreen({super.key, required this.order});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  WebSocketChannel? _channel;
  TrackingState _trackingState = TrackingState.connecting;
  
  double? _lat;
  double? _lng;
  int? _battery;
  String? _lastUpdate;
  
  DateTime? _lastReceivedTime;
  Timer? _staleTimer;
  Timer? _reconnectTimer;
  
  final MapController _mapController = MapController();
  bool _isFirstLocationReceived = false;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    
    // Check for stale locations every 10 seconds
    _staleTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) return;
      if (_lastReceivedTime != null && _trackingState == TrackingState.live) {
        final diff = DateTime.now().difference(_lastReceivedTime!);
        if (diff.inSeconds > 60) {
          setState(() {
            _trackingState = TrackingState.trackingEnded;
          });
        }
      }
    });
  }

  Future<void> _connectWebSocket() async {
    setState(() {
      _trackingState = TrackingState.connecting;
    });
    
    try {
      final token = await LocalStorage.getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication token missing')));
        }
        return;
      }

      String wsUrl = AppConfig.apiBaseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
      wsUrl += '/api/v1/ws/live-tracking?token=$token';

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      setState(() {
        _trackingState = _lat == null ? TrackingState.waitingForLocation : TrackingState.live;
      });

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'LOCATION_UPDATE' && data['data'] != null) {
              final payload = data['data'];
              if (payload['lr_number'] == widget.order.lrNumber) {
                setState(() {
                  _lat = (payload['lat'] as num?)?.toDouble();
                  _lng = (payload['lng'] as num?)?.toDouble();
                  _battery = payload['battery'] as int?;
                  _lastUpdate = payload['last_update']?.toString();
                  _lastReceivedTime = DateTime.now();
                  _trackingState = TrackingState.live;
                });

                if (_lat != null && _lng != null) {
                  if (!_isFirstLocationReceived) {
                    _isFirstLocationReceived = true;
                    _mapController.move(LatLng(_lat!, _lng!), 15.0);
                  } else {
                    _mapController.move(LatLng(_lat!, _lng!), _mapController.camera.zoom);
                  }
                }
              }
            } else if (data['type'] == 'TRACKING_ENDED' && data['data'] != null) {
              final payload = data['data'];
              if (payload['lr_number'] == widget.order.lrNumber) {
                if (mounted) {
                  setState(() {
                    _trackingState = TrackingState.trackingEnded;
                  });
                }
              }
            }
          } catch (e) {
            debugPrint('LiveTracking parse error: $e');
          }
        },
        onDone: _handleDisconnect,
        onError: (error) {
          debugPrint('LiveTracking socket error: $error');
          _handleDisconnect();
        }
      );
    } catch (e) {
      debugPrint('LiveTracking connect error: $e');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (!mounted) return;
    setState(() {
      _trackingState = TrackingState.disconnected;
    });
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _trackingState == TrackingState.disconnected) {
        setState(() {
          _trackingState = TrackingState.reconnecting;
        });
        _connectWebSocket();
      }
    });
  }

  @override
  void dispose() {
    _staleTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  Color _getStateColor() {
    switch (_trackingState) {
      case TrackingState.live: return Colors.green;
      case TrackingState.connecting:
      case TrackingState.waitingForLocation: return Colors.orange;
      case TrackingState.reconnecting: return Colors.orange;
      case TrackingState.disconnected: return Colors.red;
      case TrackingState.trackingEnded: return Colors.grey;
    }
  }

  String _getStateText() {
    switch (_trackingState) {
      case TrackingState.connecting: return 'CONNECTING';
      case TrackingState.waitingForLocation: return 'WAITING FOR LOCATION';
      case TrackingState.live: return 'LIVE';
      case TrackingState.reconnecting: return 'RECONNECTING';
      case TrackingState.disconnected: return 'DISCONNECTED';
      case TrackingState.trackingEnded: return 'TRACKING ENDED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Shipment Tracking'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header Info
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Order:', widget.order.orderNumber),
                _buildInfoRow('LR Number:', widget.order.lrNumber ?? 'N/A'),
                _buildInfoRow('Transporter:', widget.order.transporterName ?? 'N/A'),
                _buildInfoRow('Field Executive:', widget.order.assignedExecutiveName ?? 'N/A'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStateColor(),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _getStateText(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const Spacer(),
                    if (_battery != null)
                      Row(
                        children: [
                          Icon(Icons.battery_charging_full, size: 16, color: _battery! > 20 ? Colors.green : Colors.red),
                          const SizedBox(width: 4),
                          Text('$_battery%', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )
                  ],
                ),
              ],
            ),
          ),
          
          // Map
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(16.5062, 80.6480),
                    initialZoom: 6,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.shop_owner_app',
                    ),
                    if (_lat != null && _lng != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_lat!, _lng!),
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.local_shipping, 
                              color: _trackingState == TrackingState.trackingEnded ? Colors.grey : Colors.blue, 
                              size: 36
                            ),
                          )
                        ],
                      ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
                if (_trackingState == TrackingState.connecting || _trackingState == TrackingState.waitingForLocation)
                  Container(
                    color: const Color.fromRGBO(255, 255, 255, 0.7),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.green),
                          const SizedBox(height: 16),
                          Text(_getStateText(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Footer Info
          if (_lat != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Lat: ${_lat?.toStringAsFixed(4)}', style: const TextStyle(color: Colors.grey)),
                      Text('Lng: ${_lng?.toStringAsFixed(4)}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Last Updated: $_lastUpdate', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        ],
      ),
    );
  }
}
