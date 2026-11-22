import 'package:flutter/material.dart';
import '../../services/downloaded_invoices_service.dart';
import '../../core/theme/app_theme.dart';
import 'pdf_viewer_screen.dart';

class DownloadedInvoicesScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const DownloadedInvoicesScreen({super.key, this.onBack});

  @override
  State<DownloadedInvoicesScreen> createState() => _DownloadedInvoicesScreenState();
}

class _DownloadedInvoicesScreenState extends State<DownloadedInvoicesScreen> {
  List<DownloadedInvoiceItem> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloadedInvoices();
  }

  Future<void> _loadDownloadedInvoices() async {
    setState(() => _isLoading = true);
    final list = await DownloadedInvoicesService.getDownloadedInvoices();
    if (mounted) {
      setState(() {
        _invoices = list;
        _isLoading = false;
      });
    }
  }

  void _openPdfViewer(DownloadedInvoiceItem item) {
    if (item.fileExists) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            title: item.invoiceNumber,
            filePath: item.filePath,
            fileName: item.fileName,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('File Missing'),
            ],
          ),
          content: Text(
            'The PDF file "${item.fileName}" could not be found at:\n${item.filePath}\n\nIt may have been moved or deleted from your device storage.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await DownloadedInvoicesService.removeInvoice(item.invoiceNumber);
                _loadDownloadedInvoices();
              },
              child: const Text('Remove from List', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF083C28),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back',
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Downloaded Invoices',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Offline receipts stored on your device',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _loadDownloadedInvoices,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
    }

    if (_invoices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.download_done_rounded, size: 64, color: Colors.green.shade700),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Downloaded Invoices',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                'When you click "Download Receipt" after placing an order, your official PDF invoices will be saved here for offline in-app viewing.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDownloadedInvoices,
      color: AppTheme.primaryGreen,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _invoices.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _invoices[index];
          final exists = item.fileExists;

          return Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () => _openPdfViewer(item),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: exists ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf,
                            color: exists ? Colors.green.shade800 : Colors.orange.shade800,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.invoiceNumber,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: exists ? const Color(0xFF1B5E20) : Colors.black87,
                                ),
                              ),
                              if (item.orderNumber.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Order Ref: ${item.orderNumber}',
                                  style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
                                ),
                              ],
                              const SizedBox(height: 3),
                              Text(
                                'Downloaded: ${_formatDate(item.downloadedDate)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'File: ${item.fileName}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: exists ? Colors.green.shade50 : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: exists ? Colors.green.shade200 : Colors.amber.shade300,
                            ),
                          ),
                          child: Text(
                            exists ? 'Saved' : 'Missing',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: exists ? Colors.green.shade800 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade400,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Remove', style: TextStyle(fontSize: 12)),
                          onPressed: () async {
                            await DownloadedInvoicesService.removeInvoice(item.invoiceNumber);
                            _loadDownloadedInvoices();
                          },
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.fullscreen, size: 16),
                          label: const Text('Open PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => _openPdfViewer(item),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
