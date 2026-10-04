import 'package:flutter/material.dart';
import '../../models/product.dart';

class CartItem {
  final Product product;
  final String packageSize;
  int quantityBags;

  CartItem(
      {required this.product,
      required this.packageSize,
      required this.quantityBags});
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  int get totalBags => _items.fold(0, (sum, item) => sum + item.quantityBags);

  void addItem(Product product, String packageSize, int quantity) {
    final existing = _items
        .where(
            (i) => i.product.id == product.id && i.packageSize == packageSize)
        .firstOrNull;
    if (existing != null) {
      existing.quantityBags += quantity;
    } else {
      _items.add(CartItem(
          product: product, packageSize: packageSize, quantityBags: quantity));
    }
    notifyListeners();
  }

  void updateQuantity(Product product, String packageSize, int newQuantity) {
    if (newQuantity <= 0) {
      _items.removeWhere(
          (i) => i.product.id == product.id && i.packageSize == packageSize);
    } else {
      final existing = _items
          .where(
              (i) => i.product.id == product.id && i.packageSize == packageSize)
          .firstOrNull;
      if (existing != null) {
        existing.quantityBags = newQuantity;
      }
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
