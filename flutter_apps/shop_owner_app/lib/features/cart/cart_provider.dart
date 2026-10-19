import 'package:flutter/material.dart';
import '../../models/product.dart';

class CartItem {
  final Product product;
  final String packageSize;
  double quantity;
  String unit; // 'g' or 'kg'

  double get quantityKg => unit.toLowerCase() == 'g' ? quantity / 1000.0 : quantity;

  // Legacy compatibility accessor
  int get quantityBags => quantityKg.ceil();

  CartItem({
    required this.product,
    required this.packageSize,
    required this.quantity,
    this.unit = 'kg',
  });
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  double get totalQuantityKg => _items.fold(0.0, (sum, item) => sum + item.quantityKg);
  int get totalItemsCount => _items.length;

  // Legacy fallback
  int get totalBags => totalQuantityKg.ceil();

  void addItem(Product product, String packageSize, double quantity, {String unit = 'kg'}) {
    final existing = _items
        .where((i) => i.product.id == product.id && i.packageSize == packageSize && i.unit.toLowerCase() == unit.toLowerCase())
        .firstOrNull;
    if (existing != null) {
      existing.quantity += quantity;
    } else {
      _items.add(CartItem(
        product: product,
        packageSize: packageSize,
        quantity: quantity,
        unit: unit,
      ));
    }
    notifyListeners();
  }

  void updateQuantity(Product product, String packageSize, String unit, double newQuantity) {
    if (newQuantity <= 0) {
      _items.removeWhere((i) =>
          i.product.id == product.id &&
          i.packageSize == packageSize &&
          i.unit.toLowerCase() == unit.toLowerCase());
    } else {
      final existing = _items
          .where((i) =>
              i.product.id == product.id &&
              i.packageSize == packageSize &&
              i.unit.toLowerCase() == unit.toLowerCase())
          .firstOrNull;
      if (existing != null) {
        existing.quantity = newQuantity;
      }
    }
    notifyListeners();
  }

  void removeItem(CartItem item) {
    _items.remove(item);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
