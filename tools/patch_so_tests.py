p1 = 'flutter_apps/shop_owner_app/test/task_7_shop_owner_cart_test.dart'
with open(p1, 'r', encoding='utf-8') as f:
    c = f.read().replace('\r\n', '\n')

c = c.replace("cart.addItem(productA, '1 kg', 1.0);\n      expect(cart.items.length, 2);\n      expect(cart.totalQuantityCount, 3);",
              "cart.addItem(productA, '1 kg', 1.0);\n      expect(cart.items.length, 2);\n      expect(cart.totalQuantityCount, 2);")

c = c.replace("expect(cart.totalQuantityCount, 3);\n\n      // Increment item A\n      cart.incrementQuantity(itemA);\n      expect(itemA.quantity, 3.0);\n      expect(itemA.quantityKg, 3.0);\n      expect(cart.totalQuantityKg, 4.0);\n      expect(cart.totalQuantityCount, 4);",
              "expect(cart.totalQuantityCount, 2);\n\n      // Increment item A\n      cart.incrementQuantity(itemA);\n      expect(itemA.quantity, 3.0);\n      expect(itemA.quantityKg, 3.0);\n      expect(cart.totalQuantityKg, 4.0);\n      expect(cart.totalQuantityCount, 2);")

c = c.replace("// Decrement item A\n      cart.decrementQuantity(itemA);\n      expect(itemA.quantity, 2.0);\n      expect(cart.totalQuantityKg, 3.0);\n      expect(cart.totalQuantityCount, 3);",
              "// Decrement item A\n      cart.decrementQuantity(itemA);\n      expect(itemA.quantity, 2.0);\n      expect(cart.totalQuantityKg, 3.0);\n      expect(cart.totalQuantityCount, 2);")

c = c.replace("// Remove item B\n      cart.removeItem(itemB);\n      expect(cart.items.length, 1);\n      expect(cart.totalQuantityKg, 2.0);\n      expect(cart.totalQuantityCount, 2);",
              "// Remove item B\n      cart.removeItem(itemB);\n      expect(cart.items.length, 1);\n      expect(cart.totalQuantityKg, 2.0);\n      expect(cart.totalQuantityCount, 1);")

c = c.replace("// Add 2 more units of product B -> bottom navigation badge immediately displays 3\n      cart.addItem(productB, '1 kg', 2.0);\n      await tester.pump();\n      expect(\n        find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('3')),\n        findsOneWidget,\n      );",
              "// Add 2 more units of product B -> bottom navigation badge immediately displays 2\n      cart.addItem(productB, '1 kg', 2.0);\n      await tester.pump();\n      expect(\n        find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('2')),\n        findsOneWidget,\n      );")

c = c.replace("cartAlpha.addItem(productA, '1 kg', 5.0);\n\n      expect(cartAlpha.items.length, 1);\n      expect(cartAlpha.totalQuantityCount, 5);",
              "cartAlpha.addItem(productA, '1 kg', 5.0);\n\n      expect(cartAlpha.items.length, 1);\n      expect(cartAlpha.totalQuantityCount, 1);")

with open(p1, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(c)
print('Updated task_7_shop_owner_cart_test.dart')

p2 = 'flutter_apps/shop_owner_app/test/task_8_so_profile_test.dart'
with open(p2, 'r', encoding='utf-8') as f:
    c2 = f.read().replace('\r\n', '\n')

c2 = c2.replace("cart.addItem(product, '1 kg', 5.0);\n      expect(cart.totalQuantityCount, 5);",
                "cart.addItem(product, '1 kg', 5.0);\n      expect(cart.totalQuantityCount, 1);")
c2 = c2.replace("expect(cart.totalQuantityCount, 5);\n      expect(cart.totalQuantityKg, 5.0);\n      expect(cart.items.length, 1);",
                "expect(cart.totalQuantityCount, 1);\n      expect(cart.totalQuantityKg, 5.0);\n      expect(cart.items.length, 1);")

with open(p2, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(c2)
print('Updated task_8_so_profile_test.dart')

