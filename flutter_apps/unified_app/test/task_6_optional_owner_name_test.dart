import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/features/admin/shops/shops_screen.dart';
import 'package:unified_app/models/shop_model.dart';
import 'package:unified_app/providers/admin_provider.dart';

class MockAdminProviderForShops extends AdminProvider {
  Map<String, dynamic>? lastCreatedPayload;
  final List<ShopModel> _mockShops;

  MockAdminProviderForShops(this._mockShops);

  @override
  List<ShopModel> get shops => _mockShops;

  @override
  bool get isLoadingShops => false;

  @override
  Future<void> fetchShops() async {}

  @override
  Future<String?> createShop(Map<String, dynamic> payload) async {
    lastCreatedPayload = Map<String, dynamic>.from(payload);
    return null; // success
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<ShopModel> testShops = [
    ShopModel(
      id: 1,
      userId: 101,
      shopName: 'Green Valley Seeds',
      dealerCode: 'GV-01',
      marketLocation: 'Vijayawada Center',
      address: 'Main Road, Benz Circle',
      status: 'Active',
      ownerName: 'Suresh Babu',
      phone: '9848011223',
      openingStockBags: 0,
      currentStockBags: 0,
    ),
    ShopModel(
      id: 2,
      userId: 102,
      shopName: 'Kisan Krishi Kendra',
      dealerCode: 'KK-02',
      marketLocation: 'Guntur Rural',
      address: 'Near Old Bus Stand',
      status: 'Active',
      ownerName: '', // empty name
      phone: '9848099887',
      openingStockBags: 0,
      currentStockBags: 0,
    ),
  ];

  group('Task 6 — Optional Owner Full Name Widget Tests (Unified App)', () {
    testWidgets('Shops list properly renders name when present and fallback when empty',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderForShops(testShops);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AdminProvider>.value(
            value: mockProvider,
            child: const ShopsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shop 1 has ownerName 'Suresh Babu'
      expect(find.text('Owner: Suresh Babu'), findsOneWidget);

      // Shop 2 has empty ownerName -> displays 'Owner: (Not specified)'
      expect(find.text('Owner: (Not specified)'), findsOneWidget);
    });

    testWidgets('Register Dealer dialog displays Proprietor / Full Name (Optional) without required validation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockProvider = MockAdminProviderForShops(testShops);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AdminProvider>.value(
            value: mockProvider,
            child: const ShopsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Register Dealer FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.text('Register Dealer'), findsWidgets);
      expect(find.text('Proprietor / Full Name (Optional)'), findsOneWidget);

      // Fill in all required fields EXCEPT Owner Full Name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Dealer / Business Name *'),
        'New Farmers Mart',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone (10 Digits) *'),
        '9876543210',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Market / City Location *'),
        'Tenali Market',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Address *'),
        'Shop 5, Market Yard, Tenali',
      );

      // Leave Owner Full Name completely empty!
      // Tap Submit / Register Dealer button in dialog
      final submitBtn = find.widgetWithText(ElevatedButton, 'Register Dealer');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Form validation must pass without showing any error for Owner Full Name
      expect(find.text('Required'), findsNothing);

      // Verify payload sent to provider: owner_name is omitted when empty
      expect(mockProvider.lastCreatedPayload, isNotNull);
      expect(mockProvider.lastCreatedPayload!['shop_name'], equals('New Farmers Mart'));
      expect(mockProvider.lastCreatedPayload!['phone'], equals('9876543210'));
      expect(mockProvider.lastCreatedPayload!.containsKey('owner_name'), isFalse);
    });

    testWidgets('Register Dealer sends owner_name when non-empty',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockProvider = MockAdminProviderForShops(testShops);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AdminProvider>.value(
            value: mockProvider,
            child: const ShopsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Dealer / Business Name *'),
        'Aditya Seeds',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Proprietor / Full Name (Optional)'),
        'Aditya Varma',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone (10 Digits) *'),
        '9876543211',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Market / City Location *'),
        'Nuzvid',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Address *'),
        'Main Road, Nuzvid',
      );

      final submitBtn = find.widgetWithText(ElevatedButton, 'Register Dealer');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(mockProvider.lastCreatedPayload, isNotNull);
      expect(mockProvider.lastCreatedPayload!['shop_name'], equals('Aditya Seeds'));
      expect(mockProvider.lastCreatedPayload!['owner_name'], equals('Aditya Varma'));
    });
  });
}
