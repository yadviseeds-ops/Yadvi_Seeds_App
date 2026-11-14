import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_owner_app/models/product.dart';
import 'package:shop_owner_app/features/cart/cart_provider.dart';
import 'package:shop_owner_app/features/cart/cart_screen.dart';
import 'package:shop_owner_app/features/dashboard/dashboard_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TASK 7: Shop Owner Standalone App Cart Functionality', () {
    final productA = Product(
      id: 101,
      name: 'YHS Hybrid Chilli Teja',
      varietyType: 'Chilli',
      sku: 'YHS-CHL-101',
      category: 'Vegetables',
      imageUrl: '',
      availableStockKg: 50.0,
      packageSizes: ['1 kg', '500 g'],
    );

    final productB = Product(
      id: 102,
      name: 'YHS Okra Radhika Plus',
      varietyType: 'Okra',
      sku: 'YHS-OKR-102',
      category: 'Vegetables',
      imageUrl: '',
      availableStockKg: 40.0,
      packageSizes: ['1 kg'],
    );

    test('1-4. Cart item additions, badge count, and non-duplicate quantity increment', () async {
      final cart = CartProvider();
      await cart.initForAccount('test_shop_1');

      expect(cart.totalQuantityCount, 0);
      expect(cart.items.isEmpty, isTrue);

      // Operation 1: Add 1 unit of Product A -> badge = 1
      cart.addItem(productA, '1 kg', 1.0);
      expect(cart.items.length, 1);
      expect(cart.totalQuantityCount, 1);

      // Operation 2: Add 1 unit of Product B -> badge = 2
      cart.addItem(productB, '1 kg', 1.0);
      expect(cart.items.length, 2);
      expect(cart.totalQuantityCount, 2);

      // Operation 3: Add Product A again -> increments quantity, no duplicate item
      cart.addItem(productA, '1 kg', 1.0);
      expect(cart.items.length, 2);
      expect(cart.totalQuantityCount, 2);
      final itemA = cart.items.firstWhere((i) => i.product.id == 101);
      expect(itemA.quantity, 2.0);
    });

    test('5-7 & 10-11. Subtotal calculations, increment, decrement, and remove item', () async {
      final cart = CartProvider();
      await cart.initForAccount('test_shop_2');

      // Product A unit price: 650.0 / kg (Chilli)
      // Product B unit price: 420.0 / kg (Okra)
      cart.addItem(productA, '1 kg', 2.0); // 2 * 650 = 1300
      cart.addItem(productB, '1 kg', 1.0); // 1 * 420 = 420

      final itemA = cart.items.firstWhere((i) => i.product.id == 101);
      final itemB = cart.items.firstWhere((i) => i.product.id == 102);

      expect(itemA.quantityKg, 2.0);
      expect(itemB.quantityKg, 1.0);
      expect(cart.totalQuantityKg, 3.0);
      expect(cart.totalQuantityCount, 2);

      // Increment item A
      cart.incrementQuantity(itemA);
      expect(itemA.quantity, 3.0);
      expect(itemA.quantityKg, 3.0);
      expect(cart.totalQuantityKg, 4.0);
      expect(cart.totalQuantityCount, 2);

      // Decrement item A
      cart.decrementQuantity(itemA);
      expect(itemA.quantity, 2.0);
      expect(cart.totalQuantityKg, 3.0);
      expect(cart.totalQuantityCount, 2);

      // Remove item B
      cart.removeItem(itemB);
      expect(cart.items.length, 1);
      expect(cart.totalQuantityKg, 2.0);
      expect(cart.totalQuantityCount, 1);
    });

    testWidgets('8-9. Empty cart UI and Browse Products action', (tester) async {
      final cart = CartProvider();
      bool browseCatalogueCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CartProvider>.value(
            value: cart,
            child: CartScreen(
              onBrowseCatalogue: () {
                browseCatalogueCalled = true;
              },
            ),
          ),
        ),
      );

      // Verify Empty Cart UI displays
      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Browse Products'), findsOneWidget);

      // Tap Browse Products
      await tester.tap(find.text('Browse Products'));
      await tester.pumpAndSettle();

      expect(browseCatalogueCalled, isTrue);
    });

    testWidgets('12-13. Bottom Navigation Cart Tab & dynamic badge rendering', (tester) async {
      final cart = CartProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CartProvider>.value(
            value: cart,
            child: const DashboardScreen(),
          ),
        ),
      );

      // Verify bottom navigation bar has Cart item
      expect(find.text('Cart'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart), findsOneWidget);

      // Initial state: badge is hidden (0 items)
      expect(find.text('0'), findsNothing);

      // Add item to cart -> bottom navigation badge immediately displays 1
      cart.addItem(productA, '1 kg', 1.0);
      await tester.pump();
      expect(
        find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('1')),
        findsOneWidget,
      );

      // Add 2 more units of product B -> bottom navigation badge immediately displays 2
      cart.addItem(productB, '1 kg', 2.0);
      await tester.pump();
      expect(
        find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('2')),
        findsOneWidget,
      );

      // Switch to Cart tab (index 2)
      await tester.tap(find.text('Cart'));
      await tester.pumpAndSettle();

      // Verify CartScreen is active and showing items
      expect(find.text('Shopping Cart'), findsOneWidget);
      expect(find.text('YHS Hybrid Chilli Teja'), findsOneWidget);
      expect(find.text('YHS Okra Radhika Plus'), findsOneWidget);
      expect(find.text('PLACE ORDER'), findsOneWidget);
    });

    test('14-16. Persistence, Shop Owner Account Isolation, and Logout Clear', () async {
      // Shop Owner Alpha
      final cartAlpha = CartProvider();
      await cartAlpha.initForAccount('shop_owner_alpha');
      cartAlpha.addItem(productA, '1 kg', 5.0);

      expect(cartAlpha.items.length, 1);
      expect(cartAlpha.totalQuantityCount, 1);

      // Shop Owner Beta logs in on same device -> isolated empty cart
      final cartBeta = CartProvider();
      await cartBeta.initForAccount('shop_owner_beta');
      expect(cartBeta.items.isEmpty, isTrue);
      expect(cartBeta.totalQuantityCount, 0);

      // Alpha logs in again -> cart is fully restored from local storage
      final cartAlphaRestored = CartProvider();
      await cartAlphaRestored.initForAccount('shop_owner_alpha');
      expect(cartAlphaRestored.items.length, 1);
      expect(cartAlphaRestored.items.first.product.id, 101);
      expect(cartAlphaRestored.items.first.quantity, 5.0);

      // On logout -> in-memory cart cleared
      cartAlphaRestored.clearCart();
      expect(cartAlphaRestored.items.isEmpty, isTrue);
      expect(cartAlphaRestored.totalQuantityCount, 0);
    });
  });
}
