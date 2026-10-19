import 'package:flutter_test/flutter_test.dart';
import 'package:shop_owner_app/models/product.dart';
import 'package:shop_owner_app/models/order.dart';
import 'package:shop_owner_app/features/cart/cart_provider.dart';

void main() {
  group('Shop Owner App — Cart & Weight Ordering Unit Tests', () {
    test('CartProvider calculates mixed g and kg weights correctly without Bags', () {
      final cart = CartProvider();
      final p1 = Product(
        id: 1,
        name: 'Hybrid Chilli Krishna-5',
        varietyType: 'Chilli',
        sku: 'YHS-CHL-001',
        category: 'Vegetables',
        imageUrl: '',
        availableStockKg: 100.0,
      );
      final p2 = Product(
        id: 2,
        name: 'Wheat Sharbati Gold',
        varietyType: 'Sharbati',
        sku: 'YHS-WHT-002',
        category: 'Field Crops',
        imageUrl: '',
        availableStockKg: 200.0,
      );

      // Add 500 g
      cart.addItem(p1, '500g Pack', 500.0, unit: 'g');
      expect(cart.items.length, equals(1));
      expect(cart.items[0].quantity, equals(500.0));
      expect(cart.items[0].unit, equals('g'));
      expect(cart.items[0].quantityKg, equals(0.5));
      expect(cart.totalQuantityKg, equals(0.5));

      // Add 1.5 kg
      cart.addItem(p2, '1kg Pack', 1.5, unit: 'kg');
      expect(cart.items.length, equals(2));
      expect(cart.items[1].quantity, equals(1.5));
      expect(cart.items[1].unit, equals('kg'));
      expect(cart.items[1].quantityKg, equals(1.5));
      expect(cart.totalQuantityKg, equals(2.0)); // 0.5kg + 1.5kg = 2.0kg

      // Test quantity update (e.g. plus button pressed)
      cart.updateQuantity(p2, '1kg Pack', 'kg', 2.5);
      expect(cart.items[1].quantity, equals(2.5));
      expect(cart.totalQuantityKg, equals(3.0));
    });

    test('Order and OrderItem correctly parse weight and unit from JSON', () {
      final json = {
        'id': 202,
        'order_number': 'ORD-202',
        'shop_name': 'Green Agri Care',
        'shop_location': 'Hyderabad',
        'delivery_address': 'Shop 4, Market Road',
        'total_quantity_kg': 12.5,
        'total_items_count': 1,
        'status': 'Confirmed',
        'created_at': '2026-10-18T12:00:00Z',
        'items': [
          {
            'product_id': 1,
            'product_name': 'Hybrid Chilli Krishna-5',
            'sku': 'YHS-CHL-001',
            'image_url': '',
            'package_size': '250g Pouch',
            'quantity': 250.0,
            'unit': 'g',
          }
        ]
      };

      final order = Order.fromJson(json);
      expect(order.id, equals(202));
      expect(order.orderNumber, equals('ORD-202'));
      expect(order.totalQuantityKg, equals(12.5));
      expect(order.items.length, equals(1));
      expect(order.items[0].quantity, equals(250.0));
      expect(order.items[0].unit, equals('g'));
    });
  });
}
