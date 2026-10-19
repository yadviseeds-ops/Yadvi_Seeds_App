import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:unified_app/core/config/app_config.dart';
import 'package:unified_app/core/storage/local_storage.dart';
import 'package:unified_app/core/theme/app_theme.dart';
import 'package:unified_app/models/employee_model.dart';
import 'package:unified_app/providers/admin_provider.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  EmployeeModel? _selectedEmployee;
  bool _isMapView = true;
  bool _isWsConnected = false;
  WebSocketChannel? _wsChannel;
  Timer? _pollingTimer;

  // Agricultural regional center (Guntur / Vijayawada corridor)
  static const LatLng _defaultCenter = LatLng(16.5062, 80.6480);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchEmployees();
    });
    _connectWebSocket();
    _startPollingFallback();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    try {
      _wsChannel?.sink.close();
    } catch (_) {}
    super.dispose();
  }

  void _startPollingFallback() {
    // Authenticated fallback polling every 15 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        Provider.of<AdminProvider>(context, listen: false).fetchEmployees();
      }
    });
  }

  Future<void> _connectWebSocket() async {
    try {
      final token = await LocalStorage.getToken();
      if (token == null) return;

      final wsUrl = Uri.parse('${AppConfig.wsBaseUrl}/api/v1/ws/live-tracking?token=$token');
      _wsChannel = WebSocketChannel.connect(wsUrl);

      setState(() => _isWsConnected = true);

      _wsChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'LOCATION_UPDATE' && data['data'] != null) {
              final payload = data['data'];
              final empId = payload['employee_id'] as int?;
              final lat = (payload['lat'] as num?)?.toDouble();
              final lng = (payload['lng'] as num?)?.toDouble();
              final battery = (payload['battery'] as num?)?.toInt() ?? 100;
              final lastUpdate = DateTime.tryParse(payload['last_update']?.toString() ?? '') ?? DateTime.now();

              if (empId != null && lat != null && lng != null && mounted) {
                final adminProvider = Provider.of<AdminProvider>(context, listen: false);
                adminProvider.updateEmployeeLocation(empId, lat, lng, battery, lastUpdate);
                if (_selectedEmployee?.id == empId) {
                  setState(() {
                    _selectedEmployee = _selectedEmployee!.copyWith(
                      currentLat: lat,
                      currentLng: lng,
                      batteryLevel: battery,
                      lastLocationUpdate: lastUpdate,
                    );
                  });
                }
              }
            }
          } catch (e) {
            debugPrint('[LiveTracking] WS parse error: $e');
          }
        },
        onError: (err) {
          debugPrint('[LiveTracking] WS connection error: $err');
          if (mounted) setState(() => _isWsConnected = false);
        },
        onDone: () {
          if (mounted) setState(() => _isWsConnected = false);
        },
      );
    } catch (e) {
      debugPrint('[LiveTracking] WS connect error: $e');
      if (mounted) setState(() => _isWsConnected = false);
    }
  }

  bool _hasValidCoordinates(EmployeeModel emp) {
    if (emp.currentLat == null || emp.currentLng == null) return false;
    final lat = emp.currentLat!;
    final lng = emp.currentLng!;
    if (lat < -90.0 || lat > 90.0) return false;
    if (lng < -180.0 || lng > 180.0) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    return true;
  }

  String _formatTimeAgo(DateTime? dt) {
    if (dt == null) return 'Not updated today';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _centerOnAll(List<EmployeeModel> active) {
    if (active.isEmpty) {
      _mapController.move(_defaultCenter, 9.0);
      return;
    }
    double sumLat = 0.0;
    double sumLng = 0.0;
    for (var emp in active) {
      sumLat += emp.currentLat!;
      sumLng += emp.currentLng!;
    }
    final center = LatLng(sumLat / active.length, sumLng / active.length);
    _mapController.move(center, active.length == 1 ? 12.0 : 10.0);
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final allEmployees = adminProvider.employees;
    final activeGps = allEmployees.where(_hasValidCoordinates).toList();
    final noGps = allEmployees.where((e) => !_hasValidCoordinates(e)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Field Force GPS'),
        actions: [
          IconButton(
            icon: Icon(_isMapView ? Icons.format_list_bulleted : Icons.map_outlined),
            tooltip: _isMapView ? 'Show Detailed List' : 'Show Interactive Map',
            onPressed: () => setState(() => _isMapView = !_isMapView),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Locations',
            onPressed: () => adminProvider.fetchEmployees(),
          ),
        ],
      ),
      backgroundColor: AppTheme.backgroundGrey,
      body: adminProvider.isLoadingEmployees && allEmployees.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _isMapView
              ? _buildInteractiveMapView(activeGps, noGps)
              : _buildExecutiveListView(allEmployees),
    );
  }

  Widget _buildInteractiveMapView(List<EmployeeModel> activeGps, List<EmployeeModel> noGps) {
    final initialCenter = activeGps.isNotEmpty
        ? LatLng(activeGps.first.currentLat!, activeGps.first.currentLng!)
        : _defaultCenter;

    return Stack(
      children: [
        // 1. Interactive Flutter Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: activeGps.isNotEmpty ? 10.0 : 8.5,
            minZoom: 4.0,
            maxZoom: 18.0,
            onTap: (tapPosition, point) {
              if (_selectedEmployee != null) {
                setState(() => _selectedEmployee = null);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.yadvi.unified_app',
            ),
            MarkerLayer(
              markers: activeGps.map((emp) {
                final isSelected = _selectedEmployee?.id == emp.id;
                final isPresent = emp.attendanceStatus.toLowerCase() == 'present';
                final markerColor = isPresent ? AppTheme.primaryGreen : Colors.amber.shade700;

                return Marker(
                  point: LatLng(emp.currentLat!, emp.currentLng!),
                  width: 58,
                  height: 58,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedEmployee = emp);
                      _mapController.move(LatLng(emp.currentLat!, emp.currentLng!), 13.0);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isSelected)
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryGreen.withValues(alpha: 0.28),
                            ),
                          ),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: markerColor,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'FE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: emp.batteryLevel > 20 ? Colors.greenAccent.shade400 : Colors.redAccent,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // 2. Top Status Badge Pill Bar
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Row(
            children: [
              // Connection badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isWsConnected ? Colors.green : Colors.amber.shade700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isWsConnected ? 'Live' : 'Polling (15s)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isWsConnected ? Colors.green.shade800 : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Active GPS Count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(
                  '${activeGps.length} Active FE GPS',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),

              if (noGps.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    '${noGps.length} No GPS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ],
          ),
        ),

        // 3. Floating Map Controls (Right Side)
        Positioned(
          right: 12,
          top: 64,
          child: Column(
            children: [
              _buildFloatingControlButton(
                icon: Icons.center_focus_strong,
                tooltip: 'Fit All Active Markers',
                onTap: () => _centerOnAll(activeGps),
              ),
              const SizedBox(height: 8),
              _buildFloatingControlButton(
                icon: Icons.add,
                tooltip: 'Zoom In',
                onTap: () {
                  final zoom = _mapController.camera.zoom;
                  _mapController.move(_mapController.camera.center, zoom + 1);
                },
              ),
              const SizedBox(height: 8),
              _buildFloatingControlButton(
                icon: Icons.remove,
                tooltip: 'Zoom Out',
                onTap: () {
                  final zoom = _mapController.camera.zoom;
                  _mapController.move(_mapController.camera.center, zoom - 1);
                },
              ),
            ],
          ),
        ),

        // 4. Honest No-GPS Warning Card if 0 Executives have broadcast GPS
        if (activeGps.isEmpty)
          Positioned(
            top: 64,
            left: 16,
            right: 70,
            child: Card(
              color: Colors.amber.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.amber.shade300),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.location_off_outlined, color: Colors.deepOrange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No Field Executives have broadcast real GPS coordinates yet today.',
                        style: TextStyle(fontSize: 11.5, color: Colors.brown, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 5. Selected Employee Detail Card (Bottom Overlay)
        if (_selectedEmployee != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: _buildSelectedEmployeeCard(_selectedEmployee!),
          ),
      ],
    );
  }

  Widget _buildFloatingControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppTheme.textDark, size: 20),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildSelectedEmployeeCard(EmployeeModel emp) {
    final isPresent = emp.attendanceStatus.toLowerCase() == 'present';
    final hasCoords = _hasValidCoordinates(emp);

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        child: Text(
                          emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'FE',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emp.fullName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${emp.employeeCode} • ${emp.designation}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  onPressed: () => setState(() => _selectedEmployee = null),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPresent ? Colors.green.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isPresent ? Colors.green.shade200 : Colors.amber.shade200),
                  ),
                  child: Text(
                    emp.attendanceStatus,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPresent ? Colors.green.shade800 : Colors.amber.shade900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Icon(
                      Icons.battery_charging_full,
                      size: 16,
                      color: emp.batteryLevel > 20 ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 2),
                    Text('${emp.batteryLevel}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                Text(
                  _formatTimeAgo(emp.lastLocationUpdate),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hasCoords
                          ? 'Lat: ${emp.currentLat!.toStringAsFixed(5)}, Lng: ${emp.currentLng!.toStringAsFixed(5)}'
                          : 'Coordinates unavailable',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        fontWeight: hasCoords ? FontWeight.w600 : FontWeight.normal,
                        color: hasCoords ? AppTheme.textDark : AppTheme.textMuted,
                      ),
                    ),
                  ),
                  Text(
                    '${emp.distanceCoveredKm.toStringAsFixed(1)} KM',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.primaryLight),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveListView(List<EmployeeModel> employees) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: employees.length,
      itemBuilder: (ctx, i) {
        final emp = employees[i];
        final isPresent = emp.attendanceStatus.toLowerCase() == 'present';
        final hasCoords = _hasValidCoordinates(emp);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPresent ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          emp.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.battery_charging_full,
                          size: 16,
                          color: emp.batteryLevel > 20 ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text('${emp.batteryLevel}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Territory: ${emp.assignedTerritory} • Code: ${emp.employeeCode}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location, size: 18, color: AppTheme.primaryGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasCoords
                              ? 'Lat: ${emp.currentLat!.toStringAsFixed(5)}, Lng: ${emp.currentLng!.toStringAsFixed(5)}'
                              : 'Location not broadcast yet today',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: hasCoords ? FontWeight.w600 : FontWeight.normal,
                            color: hasCoords ? AppTheme.textDark : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Distance: ${emp.distanceCoveredKm.toStringAsFixed(1)} KM',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
                    ),
                    Text(
                      _formatTimeAgo(emp.lastLocationUpdate),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
