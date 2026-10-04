import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cart_provider.dart';
import '../../services/shop_service.dart';
import '../../core/config/app_config.dart';
import '../orders/my_orders_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: cart.items.isEmpty
          ? const Center(child: Text('Your cart is empty.'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Image.network(
                              '${AppConfig.apiBaseUrl}${item.product.imageUrl}',
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.image)),
                          title: Text(item.product.name),
                          subtitle: Text(
                              'Size: ${item.packageSize}\nQuantity: ${item.quantityBags} Bags'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => cart.updateQuantity(
                                item.product, item.packageSize, 0),
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
                          offset: const Offset(0, -5))
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
                      Text('Total Bags: ${cart.totalBags}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                setState(() => _isSubmitting = true);
                                try {
                                  final items = cart.items
                                      .map((i) => {
                                            'product_id': i.product.id,
                                            'package_size': i.packageSize,
                                            'quantity_bags': i.quantityBags,
                                          })
                                      .toList();
                                  await ShopService()
                                      .placeOrder(items, _notesController.text);
                                  cart.clearCart();
                                  if (context.mounted) {
                                    showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                                title:
                                                    const Text('Order Placed'),
                                                content: const Text(
                                                    'Your order has been placed successfully.'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(
                                                          context); // Close dialog
                                                      Navigator.pop(
                                                          context); // Close cart
                                                    },
                                                    child: const Text('OK'),
                                                  )
                                                ]));
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')));
                                } finally {
                                  if (mounted)
                                    setState(() => _isSubmitting = false);
                                }
                              },
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('PLACE ORDER',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                )
              ],
            ),
    );
  }
}
