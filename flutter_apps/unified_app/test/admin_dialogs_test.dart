import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/features/admin/employees/employees_screen.dart';
import 'package:unified_app/features/admin/shops/shops_screen.dart';
import 'package:unified_app/features/admin/products/products_screen.dart';
import 'package:unified_app/models/employee_model.dart';
import 'package:unified_app/models/shop_model.dart';
import 'package:unified_app/models/product_model.dart';
import 'package:unified_app/providers/admin_provider.dart';

class MockAdminProviderForDialogs extends AdminProvider {
  @override
  List<EmployeeModel> get employees => [];
  @override
  bool get isLoadingEmployees => false;

  @override
  List<ShopModel> get shops => [];
  @override
  bool get isLoadingShops => false;

  @override
  List<ProductModel> get products => [];
  @override
  bool get isLoadingProducts => false;

  @override
  Future<void> fetchEmployees() async {}
  @override
  Future<void> fetchShops() async {}
  @override
  Future<void> fetchProducts() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Panel Form Dialogs UI & Spacing Tests', () {
    testWidgets(
        '1. Add Field Executive dialog opens and renders all fields without overflow on normal screen',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderForDialogs();
      await tester.binding.setSurfaceSize(const Size(800, 700));

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: mockProvider,
          child: const MaterialApp(
            home: Scaffold(body: EmployeesScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap FloatingActionButton with label 'Add Executive'
      final addBtn = find.widgetWithText(FloatingActionButton, 'Add Executive');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('Add Field Executive'), findsOneWidget);

      // Verify all required form fields exist
      expect(find.text('Full Name *'), findsOneWidget);
      expect(find.text('Phone (10 Digits) *'), findsOneWidget);
      expect(find.text('Login Username *'), findsOneWidget);
      expect(find.text('Employee Code *'), findsOneWidget);
      expect(find.text('Assigned Territory *'), findsOneWidget);
      expect(find.text('Designation'), findsOneWidget);

      // Verify Action buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Add Executive'), findsOneWidget);

      // Trigger validation to ensure error messages render cleanly without overflow
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Executive'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '2. Add Field Executive dialog renders without overflow on small mobile screen (360x640)',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderForDialogs();
      await tester.binding.setSurfaceSize(const Size(360, 640));

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: mockProvider,
          child: const MaterialApp(
            home: Scaffold(body: EmployeesScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addBtn = find.widgetWithText(FloatingActionButton, 'Add Executive');
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('Add Field Executive'), findsOneWidget);
      expect(find.text('Full Name *'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '3. Add Shop Owner dialog opens and renders all fields without overflow on normal screen',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderForDialogs();
      await tester.binding.setSurfaceSize(const Size(800, 700));

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: mockProvider,
          child: const MaterialApp(
            home: Scaffold(body: ShopsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap FloatingActionButton with label 'Register Dealer'
      final addBtn = find.widgetWithText(FloatingActionButton, 'Register Dealer');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('Register Dealer'), findsWidgets); // FAB, Title, and Submit button

      // Verify all fields exist
      expect(find.text('Dealer / Business Name *'), findsOneWidget);
      expect(find.text('Proprietor / Full Name (Optional)'), findsOneWidget);
      expect(find.text('Phone (10 Digits) *'), findsOneWidget);
      // Username field removed for Dealer
      expect(find.text('Market / City Location *'), findsOneWidget);
      expect(find.text('Full Address *'), findsOneWidget);

      // Verify Action buttons
      expect(find.text('Cancel'), findsOneWidget);

      // Trigger validation to verify error messages display cleanly
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register Dealer'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '4. Add Shop Owner dialog renders without overflow on small mobile screen (360x640)',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderForDialogs();
      await tester.binding.setSurfaceSize(const Size(360, 640));

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: mockProvider,
          child: const MaterialApp(
            home: Scaffold(body: ShopsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addBtn = find.widgetWithText(FloatingActionButton, 'Register Dealer');
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('Dealer / Business Name *'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '5. Add Product dialog opens and renders image section & all fields without overflow on normal screen',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderForDialogs();
      await tester.binding.setSurfaceSize(const Size(800, 800));

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: mockProvider,
          child: const MaterialApp(
            home: Scaffold(body: ProductsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap FloatingActionButton with label 'Add Variety'
      final addBtn = find.widgetWithText(FloatingActionButton, 'Add Variety');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('Add Seed Variety'), findsOneWidget);

      // Verify Image picker section
      expect(find.text('Product Image'), findsOneWidget);
      expect(find.text('Select Image'), findsOneWidget);
      expect(find.text('JPG, PNG, WebP supported'), findsOneWidget);

      // Verify Form fields
      expect(find.text('Variety Name *'), findsOneWidget);
      expect(find.text('Crop / Variety Type *'), findsOneWidget);
      expect(find.text('SKU Code (Optional)'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Available Stock (kg) *'), findsOneWidget);
      expect(find.text('Package Sizes (e.g. 100g, 500g, 1kg)'), findsOneWidget);

      // Verify Action buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Add Product'), findsOneWidget);

      // Trigger validation to check error layout
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Product'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '6. Add Product dialog renders without overflow on small mobile screen (360x640)',
        (WidgetTester tester) async {
      final mockProvider = MockAdminProviderForDialogs();
      await tester.binding.setSurfaceSize(const Size(360, 640));

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: mockProvider,
          child: const MaterialApp(
            home: Scaffold(body: ProductsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addBtn = find.widgetWithText(FloatingActionButton, 'Add Variety');
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('Product Image'), findsOneWidget);
      expect(find.text('Variety Name *'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
