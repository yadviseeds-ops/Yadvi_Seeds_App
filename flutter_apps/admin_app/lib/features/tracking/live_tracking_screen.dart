import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchEmployees();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Field Force GPS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh GPS',
            onPressed: () => adminProvider.fetchEmployees(),
          ),
        ],
      ),
      backgroundColor: AppTheme.backgroundGrey,
      body: RefreshIndicator(
        onRefresh: () => adminProvider.fetchEmployees(),
        color: AppTheme.primaryGreen,
        child: adminProvider.isLoadingEmployees && adminProvider.employees.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
            : adminProvider.employees.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.gps_off_outlined, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('No executives to track', style: TextStyle(color: AppTheme.textMuted)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: adminProvider.employees.length,
                    itemBuilder: (ctx, i) {
                      final emp = adminProvider.employees[i];
                      final isPresent = emp.attendanceStatus.toLowerCase() == 'present';
                      final hasCoords = emp.currentLat != null && emp.currentLng != null;

                      return Card(
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
                              Text('Territory: ${emp.assignedTerritory} • Code: ${emp.employeeCode}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
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
                                    emp.lastLocationUpdate != null
                                        ? 'Updated: ${emp.lastLocationUpdate!.hour}:${emp.lastLocationUpdate!.minute.toString().padLeft(2, '0')}'
                                        : 'Status: ${emp.attendanceStatus}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
