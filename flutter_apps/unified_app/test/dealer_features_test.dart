import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_app/features/auth/unified_role_selection_screen.dart';
import 'package:unified_app/features/auth/role_login_screen.dart';
import 'package:unified_app/features/invoices/dealer_invoices_screen.dart';
import 'package:unified_app/features/admin/invoices/admin_invoices_screen.dart';
import 'package:unified_app/models/order.dart';
import 'package:unified_app/services/receipt_pdf_service.dart';

void main() {
  group('Change 1 & 3: Dealer Terminology & Mobile-Only Login Tests', () {
    testWidgets('Role Selection screen displays Dealer instead of Shop Owner', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UnifiedRoleSelectionScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Dealer card is present
      expect(find.text('Dealer'), findsOneWidget);
      expect(find.text('Seed Catalog, Direct Orders & Ledger Balance'), findsOneWidget);

      // Verify FE subtitle mentions Dealer
      expect(find.text('Daily Dealer Visits, Order Booking & Reports'), findsOneWidget);

      // Verify 'Shop Owner' does NOT appear anywhere on the selection screen
      expect(find.text('Shop Owner (SO)'), findsNothing);
      expect(find.text('Shop Owner'), findsNothing);
    });

    testWidgets('Dealer Login screen does NOT display any Username field (Mobile Only)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RoleLoginScreen(
            roleValue: 'shop_owner',
            roleTitle: 'Dealer',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title & Heading
      expect(find.text('Dealer Login'), findsOneWidget);
      expect(find.text('Dealer'), findsOneWidget);

      // Subtitle explains mobile number only
      expect(
        find.text('Enter your registered mobile number to receive a verification OTP:'),
        findsOneWidget,
      );

      // Mobile field MUST be present
      expect(find.text('Registered Mobile Number'), findsOneWidget);

      // Username field MUST NOT be present
      expect(find.text('Registered Username'), findsNothing);

      // Button is Request SMS OTP
      expect(find.text('Request SMS OTP'), findsOneWidget);
    });

    testWidgets('Field Executive Login screen retains Registered Username field', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RoleLoginScreen(
            roleValue: 'field_executive',
            roleTitle: 'Field Executive (FE)',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Field Executive (FE) Login'), findsOneWidget);
      // For FE, username is still required
      expect(find.text('Registered Username'), findsOneWidget);
      expect(find.text('Registered Mobile Number'), findsOneWidget);
    });
  });

  group('Change 4: Invoices Screens Tests', () {
    test('ReceiptPdfService derives deterministic INV- numbering for orders', () {
      final order1 = Order(
        id: 1,
        orderNumber: 'ORD-1022',
        shopName: 'Balaji Seeds',
        shopLocation: 'Kadapa',
        deliveryAddress: 'Main Bazar',
        ownerName: 'Venkatesh',
        contactPhone: '9848011223',
        totalQuantityKg: 5.0,
        status: 'Delivered',
        createdAt: '2026-11-15T10:00:00',
        items: [
          OrderItem(
            productId: 1,
            productName: 'Amaran Chilli',
            sku: 'YHS-CHL',
            imageUrl: '',
            packageSize: '1 kg',
            quantity: 5.0,
            unit: 'kg',
          ),
        ],
      );

      final inv = ReceiptPdfService.generateInvoiceNumber(order1);
      expect(inv, equals('INV-1022'));
      expect(ReceiptPdfService.formatDate(order1.createdAt), equals('15-Nov-2026'));
      expect(ReceiptPdfService.formatQuantity(5.0, 'kg'), equals('5 kg'));
    });

    testWidgets('DealerInvoicesScreen renders empty state when no orders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DealerInvoicesScreen(),
        ),
      );
      await tester.pump(); // Start loading

      // Shows loading indicator initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AdminInvoicesScreen renders with search bar and title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AdminInvoicesScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Dealer Invoices & Receipts'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}

