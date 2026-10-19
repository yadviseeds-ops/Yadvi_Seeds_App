import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/core/config/app_config.dart';
import 'package:unified_app/features/auth/unified_role_selection_screen.dart';
import 'package:unified_app/features/auth/admin_login_screen.dart';
import 'package:unified_app/providers/auth_provider.dart';
import 'package:unified_app/models/order_model.dart';
import 'package:unified_app/models/product_model.dart';
import 'package:unified_app/models/employee_model.dart';
import 'package:unified_app/features/cart/cart_provider.dart';
import 'package:unified_app/models/product.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Unified App — Role Selection Screen Widget Tests', () {
    testWidgets('Renders all 3 role selection cards: Admin, Field Executive (FE), Shop Owner (SO)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UnifiedRoleSelectionScreen(),
        ),
      );

      // Verify Header & Title
      expect(find.text('YADVI SEEDS'), findsOneWidget);
      expect(find.text('Unified Enterprise App'), findsOneWidget);
      expect(find.text('Select Access Module'), findsOneWidget);

      // Verify all 3 selectable cards are present
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Field Executive (FE)'), findsOneWidget);
      expect(find.text('Shop Owner (SO)'), findsOneWidget);

      // Verify connected API footer is displayed
      expect(find.textContaining('Connected API:'), findsOneWidget);
    });

    testWidgets('Server Settings button opens configurable backend dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UnifiedRoleSelectionScreen(),
        ),
      );

      final settingsBtn = find.byTooltip('Server Settings');
      expect(settingsBtn, findsOneWidget);

      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      expect(find.text('Backend Server URL'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Reset Default'), findsOneWidget);
    });

    testWidgets('Admin Login screen offers Firebase Phone OTP only without password login UI',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: AdminLoginScreen(),
          ),
        ),
      );

      // Verify OTP UI Elements
      expect(find.text('System Administration Console'), findsOneWidget);
      expect(find.text('Firebase Phone OTP Authentication'), findsOneWidget);
      expect(find.text('Admin Username'), findsOneWidget);
      expect(find.text('Registered Mobile Number'), findsOneWidget);
      expect(find.text('Send Verification OTP'), findsOneWidget);

      // Verify Password Login UI is completely absent
      expect(find.text('Password Fallback'), findsNothing);
      expect(find.text('Login with Password'), findsNothing);
      expect(find.byType(TabBar), findsNothing);
    });
  });

  group('Unified App — Data Models Unit Tests', () {
    test('OrderModel correctly parses JSON with items, kg quantity, and unit', () {
      final json = {
        'id': 101,
        'order_number': 'ORD-101',
        'shop_id': 5,
        'shop_name': 'Kisan Seeds Center',
        'shop_location': 'Indore',
        'owner_name': 'Ramesh Kumar',
        'contact_phone': '9876543210',
        'delivery_address': 'Main Mandi Road',
        'total_quantity_kg': 25.5,
        'total_items_count': 2,
        'status': 'confirmed',
        'source': 'App',
        'created_at': '2026-10-18T10:00:00Z',
        'items': [
          {
            'id': 1,
            'product_id': 10,
            'product_name': 'Bajra Hybrid 204',
            'sku': 'BJ-204',
            'image_url': '',
            'package_size': '5kg',
            'quantity': 15.5,
            'unit': 'kg',
          },
          {
            'id': 2,
            'product_id': 11,
            'product_name': 'Mustard Super 55',
            'sku': 'MS-55',
            'image_url': '',
            'package_size': '500g',
            'quantity': 500.0,
            'unit': 'g',
          }
        ]
      };

      final order = OrderModel.fromJson(json);

      expect(order.id, equals(101));
      expect(order.orderNumber, equals('ORD-101'));
      expect(order.totalQuantityKg, equals(25.5));
      expect(order.totalItemsCount, equals(2));
      expect(order.items.length, equals(2));
      expect(order.items[0].productName, equals('Bajra Hybrid 204'));
      expect(order.items[0].quantity, equals(15.5));
      expect(order.items[0].unit, equals('kg'));
      expect(order.items[1].quantity, equals(500.0));
      expect(order.items[1].unit, equals('g'));
    });

    test('ProductModel correctly parses product JSON', () {
      final json = {
        'id': 42,
        'name': 'Wheat Sharbati Gold',
        'variety_type': 'Sharbati',
        'sku': 'WHT-042',
        'category': 'Wheat',
        'image_url': 'https://example.com/wheat.jpg',
        'available_stock_bags': 150,
        'germination_rate': '95%',
        'purity': '98%',
        'maturity_days': '120 days',
        'crop_season': 'Rabi',
        'availability': 'In Stock',
        'package_sizes': '40kg',
        'is_active': true,
      };

      final product = ProductModel.fromJson(json);
      expect(product.id, equals(42));
      expect(product.name, equals('Wheat Sharbati Gold'));
      expect(product.category, equals('Wheat'));
      expect(product.varietyType, equals('Sharbati'));
      expect(product.availableStockKg, equals(150.0));
      expect(product.isActive, isTrue);
    });

    test('ProductModel parses kg stock and handles empty SKU correctly', () {
      final json = {
        'id': 99,
        'name': 'Paddy RNR-15048',
        'variety_type': 'Paddy',
        'sku': '',
        'category': 'Paddy',
        'image_url': '/public/products/paddy_sample.jpg',
        'available_stock_kg': 250.5,
        'package_sizes': '10kg, 25kg',
        'is_active': true,
      };

      final product = ProductModel.fromJson(json);
      expect(product.id, equals(99));
      expect(product.availableStockKg, equals(250.5));
      expect(product.sku, isEmpty);
      expect(product.imageUrl, equals('/public/products/paddy_sample.jpg'));
    });

    test('AppConfig provides valid API and WebSocket URLs', () {
      expect(AppConfig.apiBaseUrl, isNotEmpty);
      expect(AppConfig.wsBaseUrl, isNotEmpty);
      expect(AppConfig.wsBaseUrl.startsWith('ws://') || AppConfig.wsBaseUrl.startsWith('wss://'), isTrue);
    });

    test('EmployeeModel correctly parses real GPS coordinates and copyWith updates', () {
      final json = {
        'id': 1,
        'user_id': 2,
        'employee_code': 'YHS-EMP-002',
        'designation': 'Field Sales Officer',
        'assigned_territory': 'Guntur - Nuzvid Corridor',
        'current_lat': 16.502,
        'current_lng': 80.502,
        'battery_level': 95,
        'attendance_status': 'Present',
        'distance_covered_km': 14.5,
        'last_location_update': '2026-10-18T10:00:00Z',
        'full_name': 'Suresh Babu',
        'phone': '9848011223',
        'is_active': true,
      };

      final emp = EmployeeModel.fromJson(json);
      expect(emp.id, equals(1));
      expect(emp.fullName, equals('Suresh Babu'));
      expect(emp.currentLat, equals(16.502));
      expect(emp.currentLng, equals(80.502));
      expect(emp.batteryLevel, equals(95));
      expect(emp.attendanceStatus, equals('Present'));

      // Test real-time location update via copyWith
      final updated = emp.copyWith(
        currentLat: 16.510,
        currentLng: 80.515,
        batteryLevel: 90,
      );
      expect(updated.currentLat, equals(16.510));
      expect(updated.currentLng, equals(80.515));
      expect(updated.batteryLevel, equals(90));
      expect(updated.fullName, equals('Suresh Babu'));
    });

    test('CartProvider correctly calculates total kg weight for mixed g and kg items', () {
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
      expect(cart.items[0].quantityKg, equals(0.5));
      expect(cart.totalQuantityKg, equals(0.5));

      // Add 1.5 kg
      cart.addItem(p2, '1kg Pack', 1.5, unit: 'kg');
      expect(cart.items.length, equals(2));
      expect(cart.items[1].quantityKg, equals(1.5));
      expect(cart.totalQuantityKg, equals(2.0)); // 0.5kg + 1.5kg = 2.0kg

      // Test updating weight quantity via plus/minus (step weight)
      cart.updateQuantity(p2, '1kg Pack', 'kg', 2.5);
      expect(cart.items[1].quantity, equals(2.5));
      expect(cart.totalQuantityKg, equals(3.0)); // 0.5kg + 2.5kg = 3.0kg
    });
  });
}
