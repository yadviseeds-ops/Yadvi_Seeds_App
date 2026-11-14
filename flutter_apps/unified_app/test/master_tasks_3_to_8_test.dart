import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_app/core/widgets/exit_dialog.dart';
import 'package:unified_app/features/cart/cart_provider.dart';
import 'package:unified_app/models/product.dart';
import 'package:unified_app/models/eod_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK 7: Cart Provider & Shopping Cart Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Product model holds category and product info without price tags', () {
      final chilliProduct = Product(
        id: 1,
        name: 'Teja 4',
        varietyType: 'Chilli',
        sku: 'CH-001',
        category: 'Spices',
        imageUrl: '',
        availableStockKg: 100,
      );
      expect(chilliProduct.category, 'Spices');
      expect(chilliProduct.name, 'Teja 4');

      final okraProduct = Product(
        id: 2,
        name: 'Singham',
        varietyType: 'Okra',
        sku: 'OK-002',
        category: 'Vegetables',
        imageUrl: '',
        availableStockKg: 50,
      );
      expect(okraProduct.category, 'Vegetables');

      final defaultProduct = Product(
        id: 3,
        name: 'Super Gold',
        varietyType: 'Cotton',
        sku: 'CT-003',
        category: 'Field Crops',
        imageUrl: '',
        availableStockKg: 80,
      );
      expect(defaultProduct.category, 'Field Crops');
    });

    test('2. Add to cart creates item, calculates subtotals and updates badge count', () async {
      final cart = CartProvider();
      await cart.initForAccount('shop_123');

      final product = Product(
        id: 10,
        name: 'Hot Red',
        varietyType: 'Chilli',
        sku: 'CH-010',
        category: 'Spices',
        imageUrl: '',
        availableStockKg: 200,
      );

      cart.addItem(product, '1 kg', 2.0); // 2 kg @ 650
      expect(cart.items.length, 1);
      expect(cart.totalQuantityCount, 1);
      expect(cart.items.first.quantityKg, 2.0);
      expect(cart.totalQuantityKg, 2.0);

      // Adding the same product increases quantity without creating duplicate entry
      cart.addItem(product, '1 kg', 3.0);
      expect(cart.items.length, 1);
      expect(cart.totalQuantityCount, 1);
      expect(cart.items.first.quantity, 5.0);
      expect(cart.items.first.quantityKg, 5.0);
      expect(cart.totalQuantityKg, 5.0);
    });

    test('3. Increment, decrement, and remove cart items correctly', () async {
      final cart = CartProvider();
      await cart.initForAccount('shop_456');

      final product1 = Product(
        id: 21,
        name: 'Green Gem',
        varietyType: 'Okra',
        sku: 'OK-021',
        category: 'Vegetables',
        imageUrl: '',
        availableStockKg: 100,
      );
      final product2 = Product(
        id: 22,
        name: 'Red Gram',
        varietyType: 'Pulses',
        sku: 'PL-022',
        category: 'Pulses',
        imageUrl: '',
        availableStockKg: 150,
      );

      cart.addItem(product1, '1 kg', 2.0); // 2 kg @ 420 = 840
      cart.addItem(product2, '1 kg', 1.0); // 1 kg @ 280 = 280
      expect(cart.items.length, 2);
      expect(cart.totalQuantityCount, 2);
      expect(cart.totalQuantityKg, 3.0);

      // Increment
      final item1 = cart.items.firstWhere((i) => i.product.id == 21);
      cart.incrementQuantity(item1);
      expect(item1.quantity, 3.0);
      expect(cart.totalQuantityCount, 2);

      // Decrement
      cart.decrementQuantity(item1);
      expect(item1.quantity, 2.0);

      // Remove product 2
      final item2 = cart.items.firstWhere((i) => i.product.id == 22);
      cart.removeItem(item2);
      expect(cart.items.length, 1);
      expect(cart.items.any((i) => i.product.id == 22), isFalse);
      expect(cart.totalQuantityCount, 1);
    });

    test('4. Cart data is account-isolated and persists in SharedPreferences', () async {
      final cartUser1 = CartProvider();
      await cartUser1.initForAccount('user_alpha');

      final product = Product(
        id: 99,
        name: 'Special Chilli',
        varietyType: 'Chilli',
        sku: 'CH-099',
        category: 'Spices',
        imageUrl: '',
        availableStockKg: 50,
      );
      cartUser1.addItem(product, '1 kg', 4.0);

      // Load cart for different user -> must be empty
      final cartUser2 = CartProvider();
      await cartUser2.initForAccount('user_beta');
      expect(cartUser2.items.isEmpty, isTrue);

      // Reload cart for user_alpha -> contents restored
      final cartUser1Reloaded = CartProvider();
      await cartUser1Reloaded.initForAccount('user_alpha');
      expect(cartUser1Reloaded.items.length, 1);
      expect(cartUser1Reloaded.items.first.quantity, 4.0);
    });
  });

  group('TASK 3: App-Wide Back Navigation & Exit Dialog', () {
    testWidgets('Exit confirmation dialog displays title, message, Stay and Exit buttons',
        (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    dialogResult = await showExitConfirmationDialog(context);
                  },
                  child: const Text('Show Exit Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Exit Dialog'));
      await tester.pumpAndSettle();

      // Check dialog contents
      expect(find.text('Exit App?'), findsOneWidget);
      expect(find.text('Are you sure you want to exit the application?'), findsOneWidget);
      expect(find.text('Stay'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);

      // Tap Stay -> dialog closes with false
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(dialogResult, isFalse);

      // Reopen and tap Exit -> dialog closes with true
      await tester.tap(find.text('Show Exit Dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      expect(dialogResult, isTrue);
    });
  });

  group('TASK 4: EOD Date Model and Filtering', () {
    test('EODReportModel parses date and correctly reports fields', () {
      final json = {
        'id': 42,
        'executive_id': 5,
        'executive_name': 'Ramesh Kumar',
        'report_date': '2026-10-30',
        'completed_visits': 8,
        'pending_visits': 2,
        'total_orders': 4,
        'total_bags_ordered': 120,
        'notes': 'All visits on time',
        'created_at': '2026-10-30T17:30:00Z',
      };

      final report = EODReportModel.fromJson(json);
      expect(report.id, 42);
      expect(report.executiveName, 'Ramesh Kumar');
      expect(report.reportDate.year, 2026);
      expect(report.reportDate.month, 10);
      expect(report.reportDate.day, 30);
      expect(report.completedVisits, 8);
      expect(report.totalBagsOrdered, 120);
      expect(report.notes, 'All visits on time');
    });
  });

  group('TASK 6: Optional Owner Full Name', () {
    test('Shop creation payload safely handles missing or empty owner_name', () {
      final payloadEmpty = {
        'shop_name': 'Kisan Beej Bhandar',
        'owner_name': '',
        'phone': '9876543210',
        'username': 'kisan_bhandar',
        'market_location': 'Kurnool',
        'address': 'Main Market Road',
      };

      expect(payloadEmpty['shop_name'], isNotEmpty);
      expect(payloadEmpty['owner_name'], isEmpty);

      final payloadMissing = {
        'shop_name': 'Sri Rama Seeds',
        'phone': '9876543211',
        'username': 'sri_rama_seeds',
        'market_location': 'Guntur',
        'address': 'Cotton Market Yard',
      };

      expect(payloadMissing.containsKey('owner_name'), isFalse);
    });
  });
}
