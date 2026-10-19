import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/models/product_model.dart';
import 'package:admin_app/core/config/app_config.dart';

void main() {
  group('Admin App — Product & Config Unit Tests', () {
    test('ProductModel correctly parses product JSON with available_stock_kg', () {
      final json = {
        'id': 101,
        'name': 'Krishna-5 Hybrid Chilli',
        'variety_type': 'Chilli',
        'sku': 'YHS-CHL-001',
        'category': 'Vegetable Seeds',
        'image_url': '/public/products/sample_chilli.jpg',
        'available_stock_kg': 500.0,
        'available_stock_bags': 500,
        'germination_rate': '90% Min',
        'purity': '99% Min',
        'availability': 'In Stock',
        'package_sizes': '100g, 250g, 500g, 1kg',
        'is_active': true,
      };

      final product = ProductModel.fromJson(json);
      expect(product.id, equals(101));
      expect(product.name, equals('Krishna-5 Hybrid Chilli'));
      expect(product.varietyType, equals('Chilli'));
      expect(product.sku, equals('YHS-CHL-001'));
      expect(product.availableStockKg, equals(500.0));
      expect(product.imageUrl, equals('/public/products/sample_chilli.jpg'));
      expect(product.isActive, isTrue);
    });

    test('ProductModel parses empty SKU and falls back stock cleanly', () {
      final json = {
        'id': 102,
        'name': 'YH-222 Okra Special',
        'variety_type': 'Okra',
        'sku': '',
        'category': 'Hybrid Seeds',
        'image_url': '',
        'available_stock_bags': 120,
        'is_active': true,
      };

      final product = ProductModel.fromJson(json);
      expect(product.id, equals(102));
      expect(product.sku, isEmpty);
      expect(product.availableStockKg, equals(120.0));
      expect(product.imageUrl, isEmpty);
    });

    test('AppConfig provides valid API and WebSocket URLs', () {
      expect(AppConfig.apiBaseUrl, isNotEmpty);
      expect(AppConfig.wsBaseUrl, isNotEmpty);
      expect(AppConfig.wsBaseUrl.startsWith('ws://') || AppConfig.wsBaseUrl.startsWith('wss://'), isTrue);
    });
  });
}
