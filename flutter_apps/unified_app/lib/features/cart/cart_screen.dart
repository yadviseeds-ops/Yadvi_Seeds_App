import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/features/cart/cart_provider.dart';
import 'package:unified_app/services/shop_service.dart';
import 'package:unified_app/core/config/app_config.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Your cart is empty', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      final displayQty = item.quantity.truncateToDouble() == item.quantity
                          ? item.quantity.toInt().toString()
                          : item.quantity.toString();
                      final equivKg = item.unit == 'g' ? ' (${item.quantityKg.toStringAsFixed(3)} kg)' : '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: item.product.imageUrl.isNotEmpty
                                  ? Image.network(
                                      item.product.imageUrl.startsWith('/')
                                          ? '${AppConfig.apiBaseUrl}${item.product.imageUrl}'
                                          : item.product.imageUrl,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.green.shade50,
                                        child: const Icon(Icons.eco, color: Color(0xFF2E7D32)),
                                      ),
                                    )
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.green.shade50,
                                      child: const Icon(Icons.eco, color: Color(0xFF2E7D32)),
                                    ),
                            ),
                            title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'Packaging: ${item.packageSize}\nQuantity: $displayQty ${item.unit}$equivKg',
                              style: const TextStyle(height: 1.4),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => cart.removeItem(item),
                              tooltip: 'Remove from cart',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Delivery Notes (Optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Items: ${cart.totalItemsCount}',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          Text(
                            'Total Weight: ${cart.totalQuantityKg.toStringAsFixed(cart.totalQuantityKg.truncateToDouble() == cart.totalQuantityKg ? 0 : 2)} kg',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                setState(() => _isSubmitting = true);
                                try {
                                  final totalKg = cart.totalQuantityKg;
                                  final itemsCount = cart.totalItemsCount;
                                  final items = cart.items
                                      .map((i) => {
                                            'product_id': i.product.id,
                                            'package_size': i.packageSize,
                                            'quantity': i.quantity,
                                            'unit': i.unit,
                                          })
                                      .toList();
                                  await ShopService().placeOrder(items, _notesController.text.trim());
                                  cart.clearCart();
                                  if (context.mounted) {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Order Placed Successfully'),
                                        content: Text(
                                          'Your order for ${totalKg.toStringAsFixed(2)} kg ($itemsCount varieties) has been recorded.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context); // Close dialog
                                              Navigator.pop(context); // Close cart
                                            },
                                            child: const Text('OK'),
                                          )
                                        ],
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  String msg = e.toString();
                                  if (msg.startsWith('Exception: ')) {
                                    msg = msg.replaceFirst('Exception: ', '');
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
                                  );
                                } finally {
                                  if (mounted) setState(() => _isSubmitting = false);
                                }
                              },
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('PLACE ORDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      )
                    ],
                  ),
                )
              ],
            ),
    );
  }
}
