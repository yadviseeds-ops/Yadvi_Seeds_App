import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/eod_model.dart';
import '../../models/visit_model.dart';
import '../../providers/admin_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/local_storage.dart';

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
      final token = await LocalStorage.getToken();
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
        title: const Text(
          'EOD Report Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
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
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.bold,
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
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Report Date: ${report.reportDate.day}/${report.reportDate.month}/${report.reportDate.year}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: const Text(
                            'SUBMITTED',
                            style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat('Completed', '${report.completedVisits}', Colors.green),
                        _buildStat('Pending', '${report.pendingVisits}', Colors.orange),
                        _buildStat('Total Visits', '${report.totalVisits}', AppTheme.primaryGreen),
                        _buildStat('Bags Ordered', '${report.totalBagsOrdered}', Colors.blue),
                      ],
                    ),
                    if (report.notes != null && report.notes!.isNotEmpty) ...[
                      const Divider(height: 24),
                      const Text(
                        'EXECUTIVE NOTES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        report.notes!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Completed Visits (${completedVisits.length})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            if (completedVisits.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No completed visits found for this report date.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ),
                ),
              )
            else
              ...completedVisits.map((v) => _buildVisitCard(v, isCompleted: true)),
            const SizedBox(height: 20),
            Text(
              'Pending Visits (${pendingVisits.length})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            if (pendingVisits.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No pending visits found for this report date.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ),
                ),
              )
            else
              ...pendingVisits.map((v) => _buildVisitCard(v, isCompleted: false)),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitCard(VisitModel v, {required bool isCompleted}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
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
                    v.shopName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCompleted ? Colors.green.shade200 : Colors.orange.shade200,
                    ),
                  ),
                  child: Text(
                    v.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.green.shade800 : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            if (v.purpose.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.flag_outlined, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Purpose: ${v.purpose}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
            if (v.visitedAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Visited at ${_formatDateTime(v.visitedAt!)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
            if (v.feedback != null && v.feedback!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'Feedback: ${v.feedback}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                ),
              ),
            ],
            if (isCompleted) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              if (v.photoUrl != null && v.photoUrl!.trim().isNotEmpty) ...[
                const Row(
                  children: [
                    Icon(Icons.photo_camera_outlined, size: 16, color: AppTheme.primaryGreen),
                    SizedBox(width: 6),
                    Text(
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
                        child: Text(
                          'No shop visit photos uploaded for this visit.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
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
