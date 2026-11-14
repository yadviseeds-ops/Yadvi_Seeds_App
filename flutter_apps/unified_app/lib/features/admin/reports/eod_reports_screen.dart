import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/core/theme/app_theme.dart';
import 'package:unified_app/providers/admin_provider.dart';

import 'package:unified_app/models/eod_model.dart';
import 'package:unified_app/features/admin/reports/eod_report_details_screen.dart';

class EodReportsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const EodReportsScreen({super.key, this.onBack});

  @override
  State<EodReportsScreen> createState() => _EodReportsScreenState();
}

class _EodReportsScreenState extends State<EodReportsScreen> {
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchEodReports();
    });
  }

  void _openReportDetails(EODReportModel report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EodReportDetailsScreen(report: report),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
      helpText: 'SELECT REPORT DATE',
      confirmText: 'FILTER',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
              onSurface: AppTheme.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (_selectedDate != null &&
          _selectedDate!.year == picked.year &&
          _selectedDate!.month == picked.month &&
          _selectedDate!.day == picked.day) {
        return;
      }
      setState(() => _selectedDate = picked);
      if (mounted) {
        Provider.of<AdminProvider>(context, listen: false)
            .fetchEodReports(date: picked);
      }
    }
  }

  void _clearFilter() {
    if (_selectedDate == null) return;
    setState(() => _selectedDate = null);
    Provider.of<AdminProvider>(context, listen: false).fetchEodReports();
  }

  String _formatDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: widget.onBack,
              )
            : (Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                : null),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EOD Reports',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Daily EOD Reports',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () {
              Provider.of<AdminProvider>(context, listen: false)
                  .fetchEodReports(date: _selectedDate);
            },
          ),
          IconButton(
            icon: Icon(
              _selectedDate != null
                  ? Icons.calendar_month
                  : Icons.calendar_today_outlined,
              color: _selectedDate != null ? Colors.amberAccent : Colors.white,
            ),
            tooltip: 'Filter by Date',
            onPressed: _pickDate,
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              tooltip: 'Clear Date Filter',
              onPressed: _clearFilter,
            ),
        ],
      ),
      backgroundColor: AppTheme.backgroundGrey,
      body: Column(
        children: [
          // Active filter banner
          if (_selectedDate != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.primaryGreen.withValues(alpha: 0.12),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 18, color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filter by Date: ${_formatDate(_selectedDate!)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _clearFilter,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: [
                          Text('Clear',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(width: 2),
                          Icon(Icons.close, size: 14, color: Colors.redAccent),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  adminProvider.fetchEodReports(date: _selectedDate),
              color: AppTheme.primaryGreen,
              child: adminProvider.isLoadingEod && adminProvider.eodReports.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                  : adminProvider.eodReports.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.assessment_outlined,
                                      size: 54, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedDate != null
                                        ? 'No EOD reports submitted on this date.'
                                        : 'No EOD reports submitted yet',
                                    style: const TextStyle(
                                        color: AppTheme.textMuted, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_selectedDate != null) ...[
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: _clearFilter,
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Show All Reports'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.primaryGreen,
                                        side: const BorderSide(
                                            color: AppTheme.primaryGreen),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: adminProvider.eodReports.length,
                          itemBuilder: (ctx, i) {
                            final r = adminProvider.eodReports[i];

                            return Card(
                              key: ValueKey('eod_card_${r.id}'),
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                key: ValueKey('eod_tap_${r.id}'),
                                onTap: () => _openReportDetails(r),
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                const CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: Color(0xFFE8F5E9),
                                                  child: Icon(Icons.person,
                                                      size: 16,
                                                      color: AppTheme.primaryGreen),
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    r.executiveName,
                                                    key: ValueKey(
                                                        'eod_exec_${r.id}'),
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 15),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryGreen
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${r.reportDate.day}/${r.reportDate.month}/${r.reportDate.year}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: AppTheme
                                                          .primaryGreen),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.chevron_right,
                                                  size: 18,
                                                  color: AppTheme.textMuted),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildStat('Completed Visits',
                                                '${r.completedVisits}',
                                                Colors.green.shade700),
                                            _buildStat('Pending Visits',
                                                '${r.pendingVisits}',
                                                Colors.orange.shade800),
                                            _buildStat('Orders Booked',
                                                '${r.totalBagsOrdered}',
                                                Colors.blue.shade700),
                                          ],
                                        ),
                                      ),
                                      if (r.notes != null &&
                                          r.notes!.isNotEmpty) ...[
                                        const Divider(height: 18),
                                        Text(
                                          'Remarks: "${r.notes}"',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: AppTheme.textMuted),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ],
    );
  }
}
