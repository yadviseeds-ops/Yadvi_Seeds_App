import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_app/models/order.dart';
import 'package:unified_app/services/file_saver_service.dart';
import 'package:unified_app/services/receipt_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceiptPdfService Unit Tests', () {
    test('generateInvoiceNumber derives unique, persistent INV- identifier', () {
      final order1 = Order(
        id: 101,
        orderNumber: 'ORD-1022',
        shopName: 'Krishna Agro Agency',
        shopLocation: 'Kadapa Market',
        deliveryAddress: 'Main Road, Kadapa',
        totalQuantityKg: 10.0,
        status: 'Delivered',
        createdAt: '2026-11-15T10:30:00',
        items: [],
      );

      final order2 = Order(
        id: 55,
        orderNumber: 'ORD-8491',
        shopName: 'Venkata Seeds Store',
        shopLocation: 'Kurnool',
        deliveryAddress: 'Shop 4, Gandhi Chowk, Kurnool',
        totalQuantityKg: 5.0,
        status: 'New',
        createdAt: '2026-11-14T09:15:00',
        items: [],
      );

      final orderWithoutPrefix = Order(
        id: 99,
        orderNumber: '7721',
        shopName: 'Balaji Seeds',
        shopLocation: 'Tirupati',
        deliveryAddress: 'Bazaar Street, Tirupati',
        totalQuantityKg: 2.0,
        status: 'Confirmed',
        createdAt: '2026-11-13T14:00:00',
        items: [],
      );

      expect(ReceiptPdfService.generateInvoiceNumber(order1), equals('INV-1022'));
      expect(ReceiptPdfService.generateInvoiceNumber(order2), equals('INV-8491'));
      expect(ReceiptPdfService.generateInvoiceNumber(orderWithoutPrefix), equals('INV-7721'));
    });

    test('getReceiptFileName formats filename as YADVI_INV-<number>.pdf and is persistent', () {
      final order = Order(
        id: 1145,
        orderNumber: 'ORD-1145',
        shopName: 'Sri Balaji Agro',
        shopLocation: 'Tenali',
        deliveryAddress: 'Market Yard',
        totalQuantityKg: 3.0,
        status: 'Confirmed',
        createdAt: '2026-11-19T10:00:00',
        items: [],
      );

      // Verify exact name requested in spec
      expect(ReceiptPdfService.getReceiptFileName(order), equals('YADVI_INV-1145.pdf'));

      // Repeated calls must be completely deterministic
      expect(ReceiptPdfService.getReceiptFileName(order), equals('YADVI_INV-1145.pdf'));
      expect(ReceiptPdfService.getReceiptFileName(order), equals('YADVI_INV-1145.pdf'));
    });

    test('formatQuantity formats integer and decimal quantities with units', () {
      expect(ReceiptPdfService.formatQuantity(1.0, 'kg'), equals('1 kg'));
      expect(ReceiptPdfService.formatQuantity(25.0, 'kg'), equals('25 kg'));
      expect(ReceiptPdfService.formatQuantity(1.5, 'kg'), equals('1.5 kg'));
      expect(ReceiptPdfService.formatQuantity(1.25, 'kg'), equals('1.25 kg'));
      expect(ReceiptPdfService.formatQuantity(500.0, 'g'), equals('500 g'));
      expect(ReceiptPdfService.formatQuantity(100.0, 'g'), equals('100 g'));
      expect(ReceiptPdfService.formatQuantity(50.0, 'pkt'), equals('50 pkt'));
    });

    test('formatDate formats ISO dates to DD-MMM-YYYY', () {
      expect(ReceiptPdfService.formatDate('2026-11-15T10:30:00'), equals('15-Nov-2026'));
      expect(ReceiptPdfService.formatDate('2026-08-04T00:00:00'), equals('04-Aug-2026'));
      expect(ReceiptPdfService.formatDate('2026-01-01'), equals('01-Jan-2026'));
    });

    test('generateReceiptPdf generates valid non-empty PDF bytes with actual order info', () async {
      final sampleOrder = Order(
        id: 1022,
        orderNumber: 'ORD-1022',
        shopName: 'Sri Balaji Agro Agencies',
        shopLocation: 'Kadapa Market',
        deliveryAddress: 'Shop No. 12, Main Road, Kadapa',
        ownerName: 'Ramesh Reddy',
        contactPhone: '+91 9848012345',
        totalQuantityKg: 2.0,
        status: 'Confirmed',
        createdAt: '2026-11-15T11:00:00',
        items: [
          OrderItem(
            productId: 1,
            productName: 'Amaran F1 Hybrid Chilli',
            sku: 'YHS-CHL-001',
            imageUrl: '',
            packageSize: '1 kg pouch',
            quantity: 1.0,
            unit: 'kg',
          ),
          OrderItem(
            productId: 2,
            productName: 'Champion F1 Hybrid Chilli',
            sku: 'YHS-CHL-002',
            imageUrl: '',
            packageSize: '1 kg pouch',
            quantity: 1.0,
            unit: 'kg',
          ),
        ],
      );

      final service = ReceiptPdfService();
      final dummyLogo = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);

      final pdfBytes = await service.generateReceiptPdf(sampleOrder, customLogoBytes: dummyLogo);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));

      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('generateReceiptPdf handles missing optional buyer fields safely', () async {
      final orderWithEmptyFields = Order(
        id: 999,
        orderNumber: 'ORD-999',
        shopName: 'Bare Minimum Dealer',
        shopLocation: '',
        deliveryAddress: '',
        ownerName: null,
        contactPhone: null,
        totalQuantityKg: 1.0,
        status: 'New',
        createdAt: '2026-11-19T12:00:00',
        items: [
          OrderItem(
            productId: 1,
            productName: 'Seed Variety A',
            sku: '',
            imageUrl: '',
            packageSize: '1 kg',
            quantity: 1.0,
            unit: 'kg',
          ),
        ],
      );

      final service = ReceiptPdfService();
      final dummyLogo = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);

      final pdfBytes = await service.generateReceiptPdf(orderWithEmptyFields, customLogoBytes: dummyLogo);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('generateReceiptPdf handles multiple products and long names cleanly', () async {
      final multiProductOrder = Order(
        id: 1145,
        orderNumber: 'ORD-1145',
        shopName: 'Green Revolution Farmers Co-operative Society Limited, Central Region Branch',
        shopLocation: 'Vijayawada Agricultural Market Yard, Gate 2',
        deliveryAddress: 'Plot 45-B, Sector 3, Industrial Estate, Vijayawada, Krishna District, Andhra Pradesh',
        ownerName: 'Venkata Satyanarayana Murthy',
        contactPhone: '+91 9848099887',
        totalQuantityKg: 50.0,
        status: 'Submitted',
        createdAt: '2026-11-19T14:30:00',
        items: List.generate(
          8,
          (i) => OrderItem(
            productId: i + 1,
            productName: 'Super Hybrid Commercial Crop Seed Variety Series #$i Extra Premium Yield',
            sku: 'YHS-V$i-LONG-SKU-99',
            imageUrl: '',
            packageSize: '${(i + 1)} kg pack',
            quantity: (i + 1).toDouble(),
            unit: 'kg',
          ),
        ),
      );

      final service = ReceiptPdfService();
      final dummyLogo = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);

      final pdfBytes = await service.generateReceiptPdf(multiProductOrder, customLogoBytes: dummyLogo);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(2000));
    });

    test('Company constants match required header values', () {
      expect(ReceiptPdfService.companyName, equals('Yadvi Hybrid Seeds Pvt Ltd'));
      expect(ReceiptPdfService.companyAddress, contains('Miyapur, Hyderabad-500049'));
      expect(ReceiptPdfService.dispatchAddress, contains('Kadapa, A.P., Code-37'));
      expect(ReceiptPdfService.companyGstin, equals('37AACCY1219Q1ZV'));
      expect(ReceiptPdfService.companyState, equals('Andhra Pradesh, Code : 37'));
      expect(ReceiptPdfService.companyCin, equals('U01137TS2025PTC207349'));
      expect(ReceiptPdfService.companyContact, equals('+91-9052110028'));
    });
  });

  group('FileSaverService Platform MethodChannel Unit Tests', () {
    const channel = MethodChannel('com.yadvi.unified_app/file_saver');

    setUp(() {
      FileSaverService.isAndroidOverride = true;
    });

    tearDown(() {
      FileSaverService.isAndroidOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('savePdfToDownloads succeeds when platform returns success result', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'savePdfToDownloads') {
          final args = call.arguments as Map<dynamic, dynamic>;
          expect(args['fileName'], equals('YADVI_INV-1145.pdf'));
          expect(args['bytes'], isNotNull);
          return {
            'success': true,
            'fileName': args['fileName'],
            'path': 'content://media/external/downloads/42',
          };
        }
        return null;
      });

      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = await FileSaverService.savePdfToDownloads(
        bytes: dummyBytes,
        fileName: 'YADVI_INV-1145.pdf',
      );

      expect(result.success, isTrue);
      expect(result.fileName, equals('YADVI_INV-1145.pdf'));
      expect(result.filePath, equals('content://media/external/downloads/42'));
    });

    test('savePdfToDownloads handles platform failure cleanly', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'savePdfToDownloads') {
          throw PlatformException(
            code: 'SAVE_FAILED',
            message: 'Insufficient storage space on device',
          );
        }
        return null;
      });

      final dummyBytes = Uint8List.fromList([1, 2, 3]);
      final result = await FileSaverService.savePdfToDownloads(
        bytes: dummyBytes,
        fileName: 'YADVI_INV-1145.pdf',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('storage'));
    });

    test('Non-Android fallback saves file to temporary documents directory', () async {
      FileSaverService.isAndroidOverride = false;
      final dummyBytes = Uint8List.fromList([10, 20, 30]);
      final result = await FileSaverService.savePdfToDownloads(
        bytes: dummyBytes,
        fileName: 'YADVI_TEST_FALLBACK.pdf',
      );

      expect(result.success, isTrue);
      expect(result.fileName, equals('YADVI_TEST_FALLBACK.pdf'));
    });
  });
}
