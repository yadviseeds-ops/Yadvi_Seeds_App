import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/core/theme/app_theme.dart';
import 'package:unified_app/providers/admin_provider.dart';

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchVisits();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Visits Log'),
      ),
      backgroundColor: AppTheme.backgroundGrey,
      body: RefreshIndicator(
        onRefresh: () => adminProvider.fetchVisits(),
        color: AppTheme.primaryGreen,
        child: adminProvider.isLoadingVisits && adminProvider.visits.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
            : adminProvider.visits.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.place_outlined, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('No field visits recorded', style: TextStyle(color: AppTheme.textMuted)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: adminProvider.visits.length,
                    itemBuilder: (ctx, i) {
                      final visit = adminProvider.visits[i];
                      final isCompleted = visit.status.toLowerCase() == 'completed';

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      visit.shopName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isCompleted ? Colors.green.shade50 : Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      visit.status,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isCompleted ? Colors.green.shade800 : Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Officer: ${visit.executiveName} (${visit.employeeCode})',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Purpose: ${visit.purpose} • Location: ${visit.shopLocation}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                              if (visit.notes != null && visit.notes!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Notes: "${visit.notes}"',
                                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                              ],
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Orders Booked: ${visit.bagsOrdered}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                                  ),
                                  Text(
                                    visit.visitedAt != null
                                        ? '${visit.visitedAt!.day}/${visit.visitedAt!.month} at ${visit.visitedAt!.hour}:${visit.visitedAt!.minute.toString().padLeft(2, '0')}'
                                        : 'Scheduled: ${visit.scheduledDate.day}/${visit.scheduledDate.month}',
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
