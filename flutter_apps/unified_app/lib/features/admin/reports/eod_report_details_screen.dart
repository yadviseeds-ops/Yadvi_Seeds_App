import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/core/theme/app_theme.dart';
import 'package:unified_app/models/eod_model.dart';
import 'package:unified_app/models/visit_model.dart';
import 'package:unified_app/providers/admin_provider.dart';
import 'package:unified_app/core/config/app_config.dart';
import 'package:unified_app/core/storage/local_storage.dart';

class EodReportDetailsScreen extends StatefulWidget {
  final EODReportModel report;

  const EodReportDetailsScreen({
    super.key,
    required this.report,
  });

  @override
  State<EodReportDetailsScreen> createState() => _EodReportDetailsScreenState();
}

class _EodReportDetailsScreenState extends State<EodReportDetailsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _loadVisits();
  }

  Future<void> _loadVisits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? token;
      try {
        token = await LocalStorage.getToken().timeout(
          const Duration(milliseconds: 100),
          onTimeout: () => null,
        );
      } catch (_) {}

      if (!mounted) return;
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      await adminProvider.fetchVisits(executiveId: widget.report.executiveId);
      if (mounted) {
        setState(() {
          _authToken = token;
          _isLoading = false;
          _errorMessage = adminProvider.visitsError;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load visit details: $e';
        });
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y at $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final report = widget.report;

    final reportVisits = adminProvider.getVisitsForEodReport(report);
    final completedVisits = reportVisits
        .where((v) =>
            v.status.toLowerCase() == 'visited' ||
            v.status.toLowerCase() == 'completed')
        .toList();
    final pendingVisits = reportVisits
        .where((v) =>
            v.status.toLowerCase() != 'visited' &&
            v.status.toLowerCase() != 'completed')
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'EOD Report Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                color: Colors.white,
              ),
            ),
            Text(
              'EOD: ${report.executiveName}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('eod_details_back_button'),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            key: const ValueKey('eod_details_refresh_button'),
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Visits',
            onPressed: _loadVisits,
          ),
        ],
      ),
      body: _buildBody(completedVisits, pendingVisits),
    );
  }

  Widget _buildBody(
      List<VisitModel> completedVisits, List<VisitModel> pendingVisits) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: ValueKey('eod_details_loading'),
          color: AppTheme.primaryGreen,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 54, color: Colors.red.shade400),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadVisits,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
              ),
            ],
          ),
        ),
      );
    }

    final report = widget.report;

    return RefreshIndicator(
      onRefresh: _loadVisits,
      color: AppTheme.primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Report Summary Header Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.green.shade50,
                              child: Text(
                                report.executiveName.isNotEmpty
                                    ? report.executiveName[0].toUpperCase()
                                    : 'E',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryGreen,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.executiveName,
                                  key: const ValueKey('eod_details_exec_name'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                Text(
                                  'Executive ID: #${report.executiveId} • Report #${report.id}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            '${report.reportDate.day}/${report.reportDate.month}/${report.reportDate.year}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat('Reported Completed', '${report.completedVisits > 0 ? report.completedVisits : completedVisits.length}', Colors.green),
                        _buildStat('Reported Pending', '${(report.completedVisits > 0 || report.pendingVisits > 0) ? report.pendingVisits : pendingVisits.length}', Colors.orange),
                        _buildStat('Total Bags Booked', '${report.totalBagsOrdered > 0 ? report.totalBagsOrdered : (completedVisits.fold(0, (sum, v) => sum + v.bagsOrdered) + pendingVisits.fold(0, (sum, v) => sum + v.bagsOrdered))}', Colors.blue),
                      ],
                    ),
                    if (report.notes != null && report.notes!.isNotEmpty) ...[
                      const Divider(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.notes, size: 16, color: AppTheme.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Remarks: "${report.notes}"',
                              style: const TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Section 2: Completed Visits
            _buildSectionHeader(
              title: 'Completed Visits',
              count: completedVisits.length,
              color: Colors.green,
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(height: 8),
            if (completedVisits.isEmpty)
              _buildEmptyCard('No completed visits recorded for this reporting period.')
            else
              ...completedVisits.map((v) => _buildVisitCard(v, isCompleted: true)),

            const SizedBox(height: 24),

            // Section 3: Pending Visits
            _buildSectionHeader(
              title: 'Pending Visits',
              count: pendingVisits.length,
              color: Colors.orange,
              icon: Icons.pending_actions_outlined,
            ),
            const SizedBox(height: 8),
            if (pendingVisits.isEmpty)
              _buildEmptyCard('No pending visits recorded for this reporting period.')
            else
              ...pendingVisits.map((v) => _buildVisitCard(v, isCompleted: false)),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: Colors.grey.shade400),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitCard(VisitModel v, {required bool isCompleted}) {
    final statusColor = isCompleted ? Colors.green : Colors.orange;
    final shopDisplayName = v.shopName.isNotEmpty ? v.shopName : 'Shop #${v.shopId}';

    return Card(
      key: ValueKey('visit_card_${v.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        isCompleted ? Icons.store : Icons.storefront_outlined,
                        size: 20,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          shopDisplayName,
                          key: ValueKey(isCompleted ? 'completed_shop_${v.id}' : 'pending_shop_${v.id}'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    v.status,
                    key: ValueKey('visit_status_${v.id}'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Shop ID: #${v.shopId} • Visit ID: #${v.id}',
              key: ValueKey('visit_ids_${v.id}'),
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            if (v.shopLocation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      v.shopLocation,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isCompleted ? Icons.done_all : Icons.schedule,
                      size: 14,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCompleted && v.visitedAt != null
                          ? 'Visited: ${_formatDateTime(v.visitedAt!)}'
                          : 'Scheduled: ${_formatDateTime(v.scheduledDate)}',
                      key: ValueKey('visit_time_${v.id}'),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                if (v.bagsOrdered > 0)
                  Text(
                    '${v.bagsOrdered} bags ordered',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
              ],
            ),
            if (v.purpose.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Purpose: ${v.purpose}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
              ),
            ],
            if (v.notes != null && v.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Notes: "${v.notes}"',
                  key: ValueKey('visit_notes_${v.id}'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
            ],
            if (isCompleted) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              if (v.photoUrl != null && v.photoUrl!.trim().isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.photo_camera_outlined, size: 16, color: AppTheme.primaryGreen),
                    const SizedBox(width: 6),
                    const Text(
                      'Visit Photo Proof',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.grey.shade100,
                    child: _buildVisitPhoto(v),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.no_photography_outlined, size: 16, color: Colors.grey),
                      SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No visit photo recorded',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'No shop visit photos uploaded for this visit.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
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

  Widget _buildVisitPhoto(VisitModel v) {
    final photoUrl = v.photoUrl!.trim();
    String resolvedUrl = photoUrl.startsWith('http://') || photoUrl.startsWith('https://')
        ? photoUrl
        : '${AppConfig.apiBaseUrl}${photoUrl.startsWith('/') ? '' : '/'}$photoUrl';

    if (_authToken != null && _authToken!.isNotEmpty && !resolvedUrl.contains('token=')) {
      final sep = resolvedUrl.contains('?') ? '&' : '?';
      resolvedUrl = '$resolvedUrl${sep}token=$_authToken';
    }

    final headers = (_authToken != null && _authToken!.isNotEmpty)
        ? {'Authorization': 'Bearer $_authToken'}
        : <String, String>{};

    return GestureDetector(
      onTap: () => _showPhotoPreview(context, resolvedUrl, v.shopName, headers),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            resolvedUrl,
            headers: headers,
            key: ValueKey('visit_photo_${v.id}'),
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                ),
              );
            },
            errorBuilder: (ctx, err, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image_outlined, size: 28, color: Colors.grey.shade400),
                  const SizedBox(height: 4),
                  const Text('Failed to load visit photo', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: Colors.white, size: 12),
                  SizedBox(width: 2),
                  Text('Tap to zoom', style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoPreview(BuildContext context, String imageUrl, String title, [Map<String, String>? headers]) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              clipBehavior: Clip.none,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  headers: headers,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => Container(
                    padding: const EdgeInsets.all(32),
                    color: Colors.white,
                    child: const Text('Failed to load image preview'),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}
