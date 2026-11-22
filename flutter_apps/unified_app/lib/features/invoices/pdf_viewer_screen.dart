import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String? filePath;
  final Uint8List? pdfBytes;
  final String? fileName;

  const PdfViewerScreen({
    super.key,
    required this.title,
    this.filePath,
    this.pdfBytes,
    this.fileName,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  Uint8List? _bytes;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    if (widget.pdfBytes != null && widget.pdfBytes!.isNotEmpty) {
      setState(() {
        _bytes = widget.pdfBytes;
        _isLoading = false;
      });
      return;
    }

    if (widget.filePath != null && widget.filePath!.isNotEmpty) {
      try {
        final file = File(widget.filePath!);
        if (!await file.exists()) {
          setState(() {
            _errorMessage = 'PDF file not found on device.\nIt may have been moved or deleted.';
            _isLoading = false;
          });
          return;
        }

        final bytes = await file.readAsBytes();
        if (mounted) {
          setState(() {
            _bytes = bytes;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to read PDF file: $e';
            _isLoading = false;
          });
        }
      }
    } else {
      setState(() {
        _errorMessage = 'No PDF document provided.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E3440),
      appBar: AppBar(
        backgroundColor: const Color(0xFF083C28),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back to Invoices',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (widget.fileName != null)
              Text(
                widget.fileName!,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image_outlined, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Go Back'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    return PdfPreview(
      build: (PdfPageFormat format) async => _bytes!,
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      maxPageWidth: 700,
      pdfFileName: widget.fileName ?? 'Invoice.pdf',
      loadingWidget: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      onError: (context, error) => Center(
        child: Text(
          'Error displaying PDF: $error',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
