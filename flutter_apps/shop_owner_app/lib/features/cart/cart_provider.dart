import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/product.dart';

class CartItem {
  final Product product;
  final String packageSize;
  double quantity;
  String unit; // 'g' or 'kg'

  double get quantityKg =>
      unit.toLowerCase() == 'g' ? quantity / 1000.0 : quantity;

  // Legacy compatibility accessor
  int get quantityBags => quantityKg.ceil();


  CartItem({
    required this.product,
    required this.packageSize,
    required this.quantity,
    this.unit = 'kg',
  });

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'package_size': packageSize,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['product']),
      packageSize: json['package_size'] ?? 'Standard',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] ?? 'kg',
    );
  }
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? _accountKey;

  List<CartItem> get items => _items;

  double get totalQuantityKg =>
      _items.fold(0.0, (sum, item) => sum + item.quantityKg);


  int get totalItemsCount => _items.length;

  /// Distinct product count (number of unique product IDs in the cart)
  int get distinctProductCount => _items.map((i) => i.product.id).toSet().length;

  /// Cart badge must display the count of distinct products in the cart (not weight or quantity sum).
  int get totalQuantityCount => distinctProductCount;

  // Legacy fallback
  int get totalBags => totalQuantityKg.ceil();

  /// Initialize account-isolated cart from persistent local storage.
  Future<void> initForAccount(String accountKey) async {
    _accountKey = accountKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('cart_items_$_accountKey');
      if (savedJson != null && savedJson.isNotEmpty) {
        final List list = jsonDecode(savedJson);
        _items.clear();
        for (final itemJson in list) {
          try {
            _items.add(CartItem.fromJson(itemJson));
          } catch (_) {}
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[CartProvider] Failed to restore cart: $e');
    }
  }

  Future<void> _saveToStorage() async {
    if (_accountKey == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _items.map((i) => i.toJson()).toList();
      await prefs.setString('cart_items_$_accountKey', jsonEncode(list));
    } catch (e) {
      debugPrint('[CartProvider] Failed to persist cart: $e');
    }
  }

  void addItem(Product product, String packageSize, double quantity,
      {String unit = 'kg'}) {
    final existing = _items
        .where((i) =>
            i.product.id == product.id &&
            i.packageSize == packageSize &&
            i.unit.toLowerCase() == unit.toLowerCase())
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
    _saveToStorage();
    notifyListeners();
  }

  void incrementQuantity(CartItem item) {
    if (item.unit.toLowerCase() == 'g') {
      item.quantity += 250;
    } else {
      item.quantity += 1.0;
    }
    _saveToStorage();
    notifyListeners();
  }

  void decrementQuantity(CartItem item) {
    if (item.unit.toLowerCase() == 'g') {
      if (item.quantity > 250) {
        item.quantity -= 250;
      } else {
        _items.remove(item);
      }
    } else {
      if (item.quantity > 1.0) {
        item.quantity -= 1.0;
      } else {
        _items.remove(item);
      }
    }
    _saveToStorage();
    notifyListeners();
  }

  void updateQuantity(
      Product product, String packageSize, String unit, double newQuantity) {
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
    _saveToStorage();
    notifyListeners();
  }

  void removeItem(CartItem item) {
    _items.remove(item);
    _saveToStorage();
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _saveToStorage();
    notifyListeners();
  }
}
