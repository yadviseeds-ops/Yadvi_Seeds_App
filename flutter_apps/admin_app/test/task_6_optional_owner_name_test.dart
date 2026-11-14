import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/features/shops/shops_screen.dart';
import 'package:admin_app/models/shop_model.dart';
import 'package:admin_app/providers/admin_provider.dart';

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
  Future<bool> createShop(Map<String, dynamic> payload) async {
    lastCreatedPayload = Map<String, dynamic>.from(payload);
    return true; // success
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

  group('Task 6 — Optional Owner Full Name Widget Tests (Admin App)', () {
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

      expect(find.text('Owner: Suresh Babu'), findsOneWidget);
      expect(find.text('Owner: (Not specified)'), findsOneWidget);
    });

    testWidgets('Register Shop Owner dialog displays Owner Full Name (Optional) without required validation',
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

      expect(find.text('Register Shop Owner'), findsWidgets);
      expect(find.text('Owner Full Name (Optional)'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Shop / Business Name *'),
        'New Farmers Mart',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone (10 Digits) *'),
        '9876543210',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Login Username *'),
        'new_farmer_mart',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Market / City Location *'),
        'Tenali Market',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Address *'),
        'Shop 5, Market Yard, Tenali',
      );

      final submitBtn = find.widgetWithText(ElevatedButton, 'Register Shop Owner');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsNothing);

      expect(mockProvider.lastCreatedPayload, isNotNull);
      expect(mockProvider.lastCreatedPayload!['shop_name'], equals('New Farmers Mart'));
      expect(mockProvider.lastCreatedPayload!['phone'], equals('9876543210'));
      expect(mockProvider.lastCreatedPayload!.containsKey('owner_name'), isFalse);
    });

    testWidgets('Register Shop Owner sends owner_name when non-empty',
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
        find.widgetWithText(TextFormField, 'Shop / Business Name *'),
        'Aditya Seeds',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Owner Full Name (Optional)'),
        'Aditya Varma',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone (10 Digits) *'),
        '9876543211',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Login Username *'),
        'aditya_seeds',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Market / City Location *'),
        'Nuzvid',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Address *'),
        'Main Road, Nuzvid',
      );

      final submitBtn = find.widgetWithText(ElevatedButton, 'Register Shop Owner');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(mockProvider.lastCreatedPayload, isNotNull);
      expect(mockProvider.lastCreatedPayload!['shop_name'], equals('Aditya Seeds'));
      expect(mockProvider.lastCreatedPayload!['owner_name'], equals('Aditya Varma'));
    });
  });
}
