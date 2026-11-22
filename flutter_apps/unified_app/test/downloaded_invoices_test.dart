import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_app/services/downloaded_invoices_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadedInvoicesService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Record download and retrieve downloaded invoice items', () async {
      await DownloadedInvoicesService.recordDownload(
        invoiceNumber: 'INV-1145',
        orderNumber: 'ORD-1145',
        fileName: 'YADVI_INV-1145.pdf',
        filePath: '/storage/emulated/0/Download/YADVI_INV-1145.pdf',
        userId: 101,
      );

      final list = await DownloadedInvoicesService.getDownloadedInvoices(userId: 101);
      expect(list.length, 1);
      expect(list.first.invoiceNumber, 'INV-1145');
      expect(list.first.orderNumber, 'ORD-1145');
      expect(list.first.fileName, 'YADVI_INV-1145.pdf');
      expect(list.first.filePath, '/storage/emulated/0/Download/YADVI_INV-1145.pdf');
      expect(list.first.dealerUserId, 101);
    });

    test('2. Multiple downloads deduplicate by invoice number and keep latest at top', () async {
      await DownloadedInvoicesService.recordDownload(
        invoiceNumber: 'INV-1001',
        orderNumber: 'ORD-1001',
        fileName: 'YADVI_INV-1001.pdf',
        filePath: '/storage/INV-1001.pdf',
        userId: 101,
      );
      await DownloadedInvoicesService.recordDownload(
        invoiceNumber: 'INV-1002',
        orderNumber: 'ORD-1002',
        fileName: 'YADVI_INV-1002.pdf',
        filePath: '/storage/INV-1002.pdf',
        userId: 101,
      );

      // Re-download INV-1001 to new path
      await DownloadedInvoicesService.recordDownload(
        invoiceNumber: 'INV-1001',
        orderNumber: 'ORD-1001',
        fileName: 'YADVI_INV-1001_new.pdf',
        filePath: '/storage/new/INV-1001.pdf',
        userId: 101,
      );

      final list = await DownloadedInvoicesService.getDownloadedInvoices(userId: 101);
      expect(list.length, 2);
      expect(list.first.invoiceNumber, 'INV-1001'); // Latest on top
      expect(list.first.fileName, 'YADVI_INV-1001_new.pdf');
    });

    test('3. Dealer account isolation: invoices for Dealer A are not shown to Dealer B', () async {
      await DownloadedInvoicesService.recordDownload(
        invoiceNumber: 'INV-DEALER-A',
        orderNumber: 'ORD-A',
        fileName: 'YADVI_INV-A.pdf',
        filePath: '/storage/A.pdf',
        userId: 101,
      );

      await DownloadedInvoicesService.recordDownload(
        invoiceNumber: 'INV-DEALER-B',
        orderNumber: 'ORD-B',
        fileName: 'YADVI_INV-B.pdf',
        filePath: '/storage/B.pdf',
        userId: 202,
      );

      final listA = await DownloadedInvoicesService.getDownloadedInvoices(userId: 101);
      final listB = await DownloadedInvoicesService.getDownloadedInvoices(userId: 202);

      expect(listA.length, 1);
      expect(listA.first.invoiceNumber, 'INV-DEALER-A');

      expect(listB.length, 1);
      expect(listB.first.invoiceNumber, 'INV-DEALER-B');
    });

    test('4. Remove invoice deletes reference from list', () async {
      await DownloadedInvoicesService.recordDownload(
        invoiceNumber: 'INV-DELETE-ME',
        orderNumber: 'ORD-DELETE',
        fileName: 'delete.pdf',
        filePath: '/storage/delete.pdf',
        userId: 101,
      );

      var list = await DownloadedInvoicesService.getDownloadedInvoices(userId: 101);
      expect(list.length, 1);

      await DownloadedInvoicesService.removeInvoice('INV-DELETE-ME', userId: 101);
      list = await DownloadedInvoicesService.getDownloadedInvoices(userId: 101);
      expect(list.isEmpty, true);
    });

    test('5. DownloadedInvoiceItem fileExists returns false gracefully for non-existent file', () {
      final item = DownloadedInvoiceItem(
        invoiceNumber: 'INV-999',
        orderNumber: 'ORD-999',
        downloadedDate: DateTime.fromMillisecondsSinceEpoch(0),
        fileName: 'test.pdf',
        filePath: '/non/existent/path/test.pdf',
      );
      expect(item.fileExists, false);
    });
  });
}
