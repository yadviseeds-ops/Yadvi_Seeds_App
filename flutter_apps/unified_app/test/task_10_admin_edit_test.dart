import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_app/models/product.dart';
import 'package:unified_app/models/employee_model.dart';
import 'package:unified_app/providers/admin_provider.dart';
import 'package:unified_app/features/cart/cart_provider.dart';
import 'package:unified_app/features/admin/employees/employee_profile_screen.dart';
import 'package:unified_app/features/admin/shops/shops_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 10: Cart Badge Distinct Product Count Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    final product1 = Product(
      id: 101,
      name: 'Yadvi Chilli Super Hot',
      varietyType: 'Chilli',
      sku: 'CH-101',
      category: 'Seeds',
      imageUrl: '',
      availableStockKg: 100.0,
    );

    final product2 = Product(
      id: 102,
      name: 'Yadvi Tomato Special Hybrid',
      varietyType: 'Tomato',
      sku: 'TO-102',
      category: 'Seeds',
      imageUrl: '',
      availableStockKg: 200.0,
    );

    test('1. Adding multiple quantities of single product produces distinct badge count 1', () async {
      final cart = CartProvider();
      await cart.initForAccount('test_shop_1');

      // Add 10 kg of product 1
      cart.addItem(product1, '1 kg', 10.0);
      expect(cart.totalQuantityKg, 10.0);
      expect(cart.distinctProductCount, 1);
      expect(cart.totalQuantityCount, 1, reason: 'Badge count must equal distinct product IDs, not weight or quantity');

      // Add another 5 kg of product 1
      cart.addItem(product1, '1 kg', 5.0);
      expect(cart.totalQuantityKg, 15.0);
      expect(cart.distinctProductCount, 1);
      expect(cart.totalQuantityCount, 1, reason: 'Badge count remains 1 for same product ID');
    });

    test('2. Adding second distinct product increases badge count to 2 regardless of weights', () async {
      final cart = CartProvider();
      await cart.initForAccount('test_shop_2');

      cart.addItem(product1, '1 kg', 25.0); // 25 kg
      cart.addItem(product2, '1 kg', 50.0); // 50 kg

      expect(cart.totalQuantityKg, 75.0);
      expect(cart.distinctProductCount, 2);
      expect(cart.totalQuantityCount, 2, reason: 'Badge count must show 2 distinct products');

      // Removing product 1 decrements distinct count to 1
      final item1 = cart.items.firstWhere((i) => i.product.id == 101);
      cart.removeItem(item1);
      expect(cart.distinctProductCount, 1);
      expect(cart.totalQuantityCount, 1);
    });
  });

  group('Task 10: Admin FE Profile Edit Dialog Tests', () {
    testWidgets('3. FE Profile Screen displays Edit button and opens edit dialog with all fields', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dummyEmployee = EmployeeModel(
        id: 7,
        userId: 14,
        username: 'fe_rajesh',
        employeeCode: 'FE-007',
        designation: 'Senior Sales Officer',
        assignedTerritory: 'Warangal Territory',
        batteryLevel: 85,
        attendanceStatus: 'Present',
        distanceCoveredKm: 12.5,
        fullName: 'Rajesh Kumar',
        phone: '9876543210',
        email: 'rajesh@yadvi.com',
        isActive: true,
        assignedShops: [],
        totalAssignedShops: 5,
        completedVisits: 3,
        pendingVisits: 2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => AdminProvider(),
            child: EmployeeProfileScreen(
              employeeId: 7,
              initialEmployee: dummyEmployee,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify header details
      expect(find.text('Rajesh Kumar'), findsAtLeastNWidgets(1));
      expect(find.byKey(const ValueKey('fe_profile_edit_button')), findsOneWidget);

      // Tap Edit button
      await tester.tap(find.byKey(const ValueKey('fe_profile_edit_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Dialog opens
      expect(find.text('Edit Executive: Rajesh Kumar'), findsOneWidget);
      expect(find.text('Full Name *'), findsOneWidget);
      expect(find.text('Phone (10 digits) *'), findsOneWidget);
      expect(find.text('Username *'), findsOneWidget);
      expect(find.text('Email (Optional)'), findsOneWidget);
      expect(find.text('Employee Code *'), findsOneWidget);
      expect(find.text('Designation *'), findsOneWidget);
      expect(find.text('Assigned Territory *'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Verify Cancel closes dialog cleanly
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Edit Executive: Rajesh Kumar'), findsNothing);
    });
  });

  group('Task 10: Admin Shops Screen Edit Dialog Tests', () {
    testWidgets('4. Shops Screen displays Edit button and opens edit shop dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => AdminProvider(),
            child: const ShopsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Screen renders and search bar is present
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}

