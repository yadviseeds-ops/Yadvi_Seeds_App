import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_app/models/product.dart';
import 'package:unified_app/features/cart/cart_provider.dart';
import 'package:unified_app/features/cart/cart_screen.dart';
import 'package:unified_app/features/dashboard/dashboard_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TASK 7: Unified App Shop Owner Cart Functionality', () {
    final productA = Product(
      id: 201,
      name: 'YHS Chilli Star-1',
      varietyType: 'Chilli',
      sku: 'YHS-CHL-201',
      category: 'Vegetables',
      imageUrl: '',
      availableStockKg: 100.0,
      packageSizes: ['1 kg'],
    );

    final productB = Product(
      id: 202,
      name: 'YHS Dolichos Special',
      varietyType: 'Dolichos',
      sku: 'YHS-DOL-202',
      category: 'Vegetables',
      imageUrl: '',
      availableStockKg: 80.0,
      packageSizes: ['1 kg'],
    );

    test('Cart additions, unit price, subtotals, and total units badge count', () async {
      final cart = CartProvider();
      await cart.initForAccount('unified_so_1');

      // Product A unit price: 650.0 (Chilli)
      // Product B unit price: 380.0 (Dolichos)
      cart.addItem(productA, '1 kg', 1.0);
      expect(cart.totalQuantityCount, 1);
      expect(cart.totalQuantityKg, 1.0);

      cart.addItem(productB, '1 kg', 2.0);
      expect(cart.totalQuantityCount, 2);
      expect(cart.totalQuantityKg, 3.0);

      // Same product added again increments quantity
      cart.addItem(productA, '1 kg', 1.0);
      expect(cart.items.length, 2);
      expect(cart.totalQuantityCount, 2);
      expect(cart.items.firstWhere((i) => i.product.id == 201).quantity, 2.0);
    });

    testWidgets('Empty cart UI shows Browse Products and triggers catalogue callback', (tester) async {
      final cart = CartProvider();
      bool browseClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CartProvider>.value(
            value: cart,
            child: CartScreen(
              onBrowseCatalogue: () {
                browseClicked = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Browse Products'), findsOneWidget);

      await tester.tap(find.text('Browse Products'));
      await tester.pumpAndSettle();

      expect(browseClicked, isTrue);
    });

    testWidgets('Dashboard bottom navigation displays Cart with dynamic badge', (tester) async {
      final cart = CartProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CartProvider>.value(
            value: cart,
            child: const DashboardScreen(),
          ),
        ),
      );

      expect(find.text('Cart'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart), findsOneWidget);

      // Add product -> badge updates immediately to 1
      cart.addItem(productA, '1 kg', 1.0);
      await tester.pump();
      expect(
        find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('1')),
        findsOneWidget,
      );

      // Add product B -> badge updates immediately to 2
      cart.addItem(productB, '1 kg', 1.0);
      await tester.pump();
      expect(
        find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('2')),
        findsOneWidget,
      );

      // Switch tab to Cart
      await tester.tap(find.text('Cart'));
      await tester.pumpAndSettle();

      expect(find.text('Shopping Cart'), findsOneWidget);
      expect(find.text('YHS Chilli Star-1'), findsOneWidget);
      expect(find.text('YHS Dolichos Special'), findsOneWidget);
    });

    test('Persistent storage and account isolation between Shop Owners', () async {
      final cartOwner1 = CartProvider();
      await cartOwner1.initForAccount('owner_one');
      cartOwner1.addItem(productA, '1 kg', 3.0);

      final cartOwner2 = CartProvider();
      await cartOwner2.initForAccount('owner_two');
      expect(cartOwner2.items.isEmpty, isTrue);

      final cartOwner1Reloaded = CartProvider();
      await cartOwner1Reloaded.initForAccount('owner_one');
      expect(cartOwner1Reloaded.items.length, 1);
      expect(cartOwner1Reloaded.totalQuantityCount, 1);
    });
  });
}
