import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/features/cart/cart_provider.dart';
import 'package:unified_app/services/shop_service.dart';
import 'package:unified_app/services/receipt_pdf_service.dart';
import 'package:unified_app/core/widgets/product_image.dart';

class CartScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onBrowseCatalogue;

  const CartScreen({super.key, this.onBack, this.onBrowseCatalogue});

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

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _handleBack,
        ),
        title: const Text('Shopping Cart', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (cart.items.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Cart'),
                    content: const Text('Are you sure you want to remove all items from your cart?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () {
                          cart.clearCart();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_sweep, size: 18, color: Colors.redAccent),
              label: const Text('Clear', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      backgroundColor: const Color(0xFFF4F6F5),
      body: cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Your cart is empty',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Browse our certified seed catalog and add items to your cart.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F422C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () {
                      if (widget.onBrowseCatalogue != null) {
                        widget.onBrowseCatalogue!();
                      } else {
                        _handleBack();
                      }
                    },
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Browse Products', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      final displayQty = item.quantity.truncateToDouble() == item.quantity
                          ? item.quantity.toInt().toString()
                          : item.quantity.toString();

                      return Card(
                        key: ValueKey('cart_item_${item.product.id}_${item.packageSize}'),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: ProductImage(
                                      imageUrl: item.product.imageUrl,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      placeholder: Container(
                                        width: 64,
                                        height: 64,
                                        color: Colors.green.shade50,
                                        child: const Icon(Icons.eco, color: Color(0xFF2E7D32)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Pack Size: ${item.packageSize} | SKU: ${item.product.sku}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('Category: ' + item.product.category, style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    tooltip: 'Remove',
                                    onPressed: () => cart.removeItem(item),
                                  ),
                                ],
                              ),
                              const Divider(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Quantity +/- Controls
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove, size: 18),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => cart.decrementQuantity(item),
                                          tooltip: 'Decrease quantity',
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            '$displayQty ${item.unit}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add, size: 18),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => cart.incrementQuantity(item),
                                          tooltip: 'Increase quantity',
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Item Total Weight
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Weight',
                                        style: TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      Text(
                                        '${item.quantityKg.toStringAsFixed(item.quantityKg.truncateToDouble() == item.quantityKg ? 1 : 2)} kg',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF0F422C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Bottom Checkout / Subtotal Panel
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Delivery Notes (Optional)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Items: ${cart.totalItemsCount} (${cart.totalQuantityKg.toStringAsFixed(1)} kg)',
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Total Weight', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text(
                                  '${cart.totalQuantityKg.toStringAsFixed(1)} kg',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D4A32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                                    final placedOrder = await ShopService().placeOrder(items, _notesController.text.trim());
                                    cart.clearCart();
                                    if (context.mounted) {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (dialogCtx) {
                                          bool isDownloading = false;
                                          return StatefulBuilder(
                                            builder: (context, setDialogState) => AlertDialog(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              title: Row(
                                                children: [
                                                  Icon(Icons.check_circle, color: Colors.green[700], size: 28),
                                                  const SizedBox(width: 8),
                                                  const Expanded(
                                                    child: Text(
                                                      'Order Placed Successfully',
                                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Your order (${placedOrder.orderNumber}) for ${totalKg.toStringAsFixed(2)} kg ($itemsCount varieties) has been recorded.',
                                                    style: const TextStyle(fontSize: 14),
                                                  ),
                                                  const SizedBox(height: 14),
                                                  Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.shade50,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.green.shade200),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          'Invoice No: ${ReceiptPdfService.generateInvoiceNumber(placedOrder)}',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.green.shade900,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 3),
                                                        Text(
                                                          'Download or share your official A4 PDF receipt.',
                                                          style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton.icon(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFF1B5E20),
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                      ),
                                                      icon: isDownloading
                                                          ? const SizedBox(
                                                              width: 18,
                                                              height: 18,
                                                              child: CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color: Colors.white,
                                                              ),
                                                            )
                                                          : const Icon(Icons.download, size: 20),
                                                      label: Text(
                                                        isDownloading ? 'Generating receipt...' : 'Download Receipt',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                      ),
                                                      onPressed: isDownloading
                                                          ? null
                                                          : () async {
                                                              setDialogState(() => isDownloading = true);
                                                              try {
                                                                await ReceiptPdfService().downloadReceiptToDownloads(
                                                                  dialogCtx,
                                                                  placedOrder,
                                                                );
                                                              } finally {
                                                                if (dialogCtx.mounted) {
                                                                  setDialogState(() => isDownloading = false);
                                                                }
                                                              }
                                                            },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(dialogCtx);
                                                  },
                                                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    }
                                  } catch (e) {
                                    String msg = e.toString();
                                    if (msg.startsWith('Exception: ')) {
                                      msg = msg.replaceFirst('Exception: ', '');
                                    }
                                    if (!context.mounted) return;
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
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
