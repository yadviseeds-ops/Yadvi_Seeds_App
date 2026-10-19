import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';

class EodReportsScreen extends StatefulWidget {
  const EodReportsScreen({super.key});

  @override
  State<EodReportsScreen> createState() => _EodReportsScreenState();
}

class _EodReportsScreenState extends State<EodReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchEodReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily EOD Reports'),
      ),
      backgroundColor: AppTheme.backgroundGrey,
      body: RefreshIndicator(
        onRefresh: () => adminProvider.fetchEodReports(),
        color: AppTheme.primaryGreen,
        child: adminProvider.isLoadingEod && adminProvider.eodReports.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
            : adminProvider.eodReports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assessment_outlined, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('No EOD reports submitted yet', style: TextStyle(color: AppTheme.textMuted)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: adminProvider.eodReports.length,
                    itemBuilder: (ctx, i) {
                      final r = adminProvider.eodReports[i];

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    r.executiveName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    '${r.reportDate.day}/${r.reportDate.month}/${r.reportDate.year}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStat('Completed Visits', '${r.completedVisits}', Colors.green),
                                  _buildStat('Pending Visits', '${r.pendingVisits}', Colors.orange),
                                  _buildStat('Orders Booked', '${r.totalBagsOrdered}', Colors.blue),
                                ],
                              ),
                              if (r.notes != null && r.notes!.isNotEmpty) ...[
                                const Divider(height: 18),
                                Text(
                                  'Remarks: "${r.notes}"',
                                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ],
    );
  }
}
