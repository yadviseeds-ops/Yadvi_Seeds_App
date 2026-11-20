import 'file_saver_service.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart' show BuildContext, ScaffoldMessenger, SnackBar, Color, Colors, Text;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order.dart';

class ReceiptPdfService {
  static const String companyName = 'Yadvi Hybrid Seeds Pvt Ltd';
  static const String companyAddress =
      'Flat No.302, Plot No-21, Sri Surya Nilayam, Sai Nagar Colony, Maqtha Mahaboobpet, Miyapur, Hyderabad-500049.';
  static const String dispatchAddress = 'F-3, IE, Kadapa, A.P., Code-37';
  static const String companyGstin = '37AACCY1219Q1ZV';
  static const String companyState = 'Andhra Pradesh, Code : 37';
  static const String companyCin = 'U01137TS2025PTC207349';
  static const String companyContact = '+91-9052110028';

  /// Deterministically derives a unique, persistent invoice number from the order
    /// Formats the official download filename for an order (e.g. YADVI_INV-1145.pdf)
  static String getReceiptFileName(Order order) {
    final inv = generateInvoiceNumber(order);
    return 'YADVI_$inv.pdf';
  }

static String generateInvoiceNumber(Order order) {
    if (order.orderNumber.isNotEmpty) {
      final clean = order.orderNumber.replaceAll('ORD-', '').trim();
      return 'INV-$clean';
    } else if (order.id > 0) {
      return 'INV-${order.id}';
    } else {
      return 'INV-001';
    }
  }

  /// Formats a date string to clean DD-MMM-YYYY representation
  static String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) {
      return _formatDateTime(DateTime.now());
    }
    final dt = DateTime.tryParse(dateStr.trim());
    if (dt == null) return dateStr;
    return _formatDateTime(dt);
  }

  static String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year.toString();
    return '$day-$month-$year';
  }

  /// Formats quantity cleanly with unit (e.g. "1 kg", "500 g", "1.5 kg")
  static String formatQuantity(double quantity, String? unit) {
    final cleanUnit = (unit != null && unit.trim().isNotEmpty) ? unit.trim() : 'kg';
    if (quantity % 1 == 0) {
      return '${quantity.toInt()} $cleanUnit';
    } else {
      final str = quantity.toStringAsFixed(2);
      final trimmed = str.endsWith('.00')
          ? str.substring(0, str.length - 3)
          : (str.endsWith('0') ? str.substring(0, str.length - 1) : str);
      return '$trimmed $cleanUnit';
    }
  }

  /// Generates the complete receipt PDF as raw bytes
  Future<Uint8List> generateReceiptPdf(Order order, {Uint8List? customLogoBytes}) async {
    final pdf = pw.Document(
      title: 'Receipt_${generateInvoiceNumber(order)}',
      author: companyName,
    );

    // Load company logo if available
    pw.MemoryImage? logoImage;
    if (customLogoBytes != null && customLogoBytes.isNotEmpty) {
      logoImage = pw.MemoryImage(customLogoBytes);
    } else {
      try {
        final byteData = await rootBundle.load('assets/images/yhs_invoice_logo.png');
        logoImage = pw.MemoryImage(byteData.buffer.asUint8List());
      } catch (_) {
        // Fallback gracefully if running in unit test environment without rootBundle assets
      }
    }

    final invoiceNumber = generateInvoiceNumber(order);
    final invoiceDate = formatDate(order.createdAt);

    // Primary brand color
    const brandPrimary = PdfColor.fromInt(0xFF1B5E20); // Dark Green
    const neutralDark = PdfColor.fromInt(0xFF212121);
    const neutralLight = PdfColor.fromInt(0xFFF5F5F5);
    const borderColor = PdfColor.fromInt(0xFFCCCCCC);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderColor, width: 1.2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. TOP HEADER - COMPANY DETAILS & LOGO
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 65,
                          height: 65,
                          margin: const pw.EdgeInsets.only(right: 14),
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              companyName,
                              style: pw.TextStyle(
                                fontSize: 15,
                                fontWeight: pw.FontWeight.bold,
                                color: brandPrimary,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              companyAddress,
                              style: const pw.TextStyle(fontSize: 7.5, color: neutralDark),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Dispatch: $dispatchAddress',
                              style: const pw.TextStyle(fontSize: 7.5, color: neutralDark),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Row(
                              children: [
                                pw.Text(
                                  'GSTIN/UIN: $companyGstin',
                                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: neutralDark),
                                ),
                                pw.SizedBox(width: 12),
                                pw.Text(
                                  'State: $companyState',
                                  style: const pw.TextStyle(fontSize: 7.5, color: neutralDark),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 2),
                            pw.Row(
                              children: [
                                pw.Text(
                                  'CIN: $companyCin',
                                  style: const pw.TextStyle(fontSize: 7.5, color: neutralDark),
                                ),
                                pw.SizedBox(width: 12),
                                pw.Text(
                                  'Contact: $companyContact',
                                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: neutralDark),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. DOCUMENT TITLE BANNER
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  alignment: pw.Alignment.center,
                  decoration: const pw.BoxDecoration(
                    color: neutralLight,
                    border: pw.Border.symmetric(
                      horizontal: pw.BorderSide(color: borderColor, width: 0.8),
                    ),
                  ),
                  child: pw.Text(
                    'ORDER RECEIPT / BILL OF SUPPLY',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: brandPrimary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // 3. INVOICE META & BUYER DETAILS SECTION
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: borderColor, width: 0.8),
                    ),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // BUYER (BILL TO)
                      pw.Expanded(
                        flex: 6,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              right: pw.BorderSide(color: borderColor, width: 0.8),
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'BUYER (BILL TO)',
                                style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: brandPrimary,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              if (order.shopName.isNotEmpty) ...[
                                pw.Text(
                                  'Dealer: ${order.shopName}',
                                  style: pw.TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: neutralDark,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                              ],
                              if (order.ownerName != null && order.ownerName!.isNotEmpty && order.ownerName != order.shopName) ...[
                                pw.Text(
                                  'Proprietor: ${order.ownerName}',
                                  style: const pw.TextStyle(fontSize: 8, color: neutralDark),
                                ),
                                pw.SizedBox(height: 2),
                              ],
                              if (order.deliveryAddress.isNotEmpty) ...[
                                pw.Text(
                                  'Address: ${order.deliveryAddress}',
                                  style: const pw.TextStyle(fontSize: 8, color: neutralDark),
                                ),
                                pw.SizedBox(height: 2),
                              ] else if (order.shopLocation.isNotEmpty) ...[
                                pw.Text(
                                  'Location: ${order.shopLocation}',
                                  style: const pw.TextStyle(fontSize: 8, color: neutralDark),
                                ),
                                pw.SizedBox(height: 2),
                              ],
                              if (order.contactPhone != null && order.contactPhone!.isNotEmpty) ...[
                                pw.Text(
                                  'Contact: ${order.contactPhone}',
                                  style: const pw.TextStyle(fontSize: 8, color: neutralDark),
                                ),
                                pw.SizedBox(height: 2),
                              ],
                              pw.Text(
                                'State: Andhra Pradesh, Code : 37',
                                style: const pw.TextStyle(fontSize: 8, color: neutralDark),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // INVOICE DETAILS
                      pw.Expanded(
                        flex: 4,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildMetaRow('Invoice No.:', invoiceNumber, isBold: true),
                              pw.SizedBox(height: 4),
                              _buildMetaRow('Dated:', invoiceDate),
                              pw.SizedBox(height: 4),
                              _buildMetaRow('Order Ref:', order.orderNumber),
                              pw.SizedBox(height: 4),
                              _buildMetaRow('Status:', order.status),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. PRODUCT DETAILS TABLE
                pw.Expanded(
                  child: pw.Container(
                    child: _buildItemsTable(order.items, neutralLight, neutralDark, borderColor, brandPrimary),
                  ),
                ),

                // 5. TOTAL SUMMARY ROW
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: const pw.BoxDecoration(
                    color: neutralLight,
                    border: pw.Border(
                      top: pw.BorderSide(color: borderColor, width: 0.8),
                      bottom: pw.BorderSide(color: borderColor, width: 0.8),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total Items: ${order.items.length} varieties',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: neutralDark,
                        ),
                      ),
                      pw.Text(
                        'Total Quantity: ${formatQuantity(order.totalQuantityKg, 'kg')}',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: brandPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                // 6. BOTTOM ACKNOWLEDGEMENT FOOTER
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'This is a computer-generated order receipt from Yadvi Hybrid Seeds.',
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'Thank you for your business.',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: brandPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildMetaRow(String label, String value, {bool isBold = false}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 65,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.black,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildItemsTable(
    List<OrderItem> items,
    PdfColor headerBg,
    PdfColor textColor,
    PdfColor tableBorderColor,
    PdfColor primaryColor,
  ) {
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: tableBorderColor, width: 0.5),
        verticalInside: pw.BorderSide(color: tableBorderColor, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(40), // Sl No
        1: pw.FlexColumnWidth(5),   // Description
        2: pw.FlexColumnWidth(2),   // Package Size
        3: pw.FlexColumnWidth(2.2), // Quantity
      },
      children: [
        // Table Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerBg),
          children: [
            _buildTableHeaderCell('Sl No.', align: pw.TextAlign.center),
            _buildTableHeaderCell('Description of Goods / Hybrid Seeds'),
            _buildTableHeaderCell('Package Size', align: pw.TextAlign.center),
            _buildTableHeaderCell('Quantity', align: pw.TextAlign.right),
          ],
        ),
        // Table Rows
        ...items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;
          final qtyFormatted = formatQuantity(item.quantity, item.unit);
          final pkgSize = (item.packageSize.isNotEmpty && item.packageSize.toLowerCase() != 'standard')
              ? item.packageSize
              : '-';

          return pw.TableRow(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  '$index',
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item.productName.isNotEmpty ? item.productName : 'Hybrid Seed Product',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (item.sku.isNotEmpty)
                      pw.Text(
                        'SKU: ${item.sku}',
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                      ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  pkgSize,
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  qtyFormatted,
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      alignment: align == pw.TextAlign.center
          ? pw.Alignment.center
          : (align == pw.TextAlign.right ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor.fromInt(0xFF1B5E20),
        ),
      ),
    );
  }

  /// Generates the PDF and saves it directly into the mobile device's public Downloads directory
  Future<FileSaveResult> downloadReceiptToDownloads(
    BuildContext context,
    Order order,
  ) async {
    try {
      final bytes = await generateReceiptPdf(order);
      final fileName = getReceiptFileName(order);
      final result = await FileSaverService.savePdfToDownloads(
        bytes: bytes,
        fileName: fileName,
      );

      if (!context.mounted) return result;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt downloaded successfully: ${result.fileName}'),
            backgroundColor: const Color(0xFF1B5E20),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download receipt: ${result.errorMessage ?? "Unknown error"}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return result;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate receipt: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return FileSaveResult(
        success: false,
        fileName: getReceiptFileName(order),
        errorMessage: e.toString(),
      );
    }
  }

  /// Downloads receipt directly to device's public Downloads folder
  Future<void> downloadOrShareReceipt(BuildContext context, Order order) async {
    await downloadReceiptToDownloads(context, order);
  }

  /// Native PDF print / save preview handler
  Future<void> printReceipt(BuildContext context, Order order) async {
    try {
      final invoiceNum = generateInvoiceNumber(order);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => generateReceiptPdf(order),
        name: 'Receipt_$invoiceNum.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to preview receipt: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

