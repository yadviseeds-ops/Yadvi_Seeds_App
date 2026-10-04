import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../cart/cart_provider.dart';
import '../../core/config/app_config.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  String? _selectedSize;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.product.packageSizes.isNotEmpty) {
      _selectedSize = widget.product.packageSizes.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Image.network('${AppConfig.apiBaseUrl}${p.imageUrl}',
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image, size: 100))),
            const SizedBox(height: 16),
            Text(p.name,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(p.varietyType,
                style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 16),
            _buildInfoRow('SKU', p.sku),
            _buildInfoRow('Category', p.category),
            _buildInfoRow('Stock', '${p.availableStockBags} Bags'),
            _buildInfoRow('Germination', p.germinationRate),
            _buildInfoRow('Purity', p.purity),
            _buildInfoRow('Maturity', p.maturityDays),
            const SizedBox(height: 16),
            const Text('Description',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(p.description),
            const SizedBox(height: 24),
            const Text('Package Size',
                style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _selectedSize,
              isExpanded: true,
              items: p.packageSizes
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedSize = v),
            ),
            const SizedBox(height: 16),
            const Text('Quantity (Bags)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                IconButton(
                    onPressed: () => setState(() {
                          if (_quantity > 1) _quantity--;
                        }),
                    icon: const Icon(Icons.remove_circle_outline)),
                Text('$_quantity',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                    onPressed: () => setState(() => _quantity++),
                    icon: const Icon(Icons.add_circle_outline)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _selectedSize == null
                    ? null
                    : () {
                        Provider.of<CartProvider>(context, listen: false)
                            .addItem(p, _selectedSize!, _quantity);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Added $_quantity bag(s) to cart')));
                        Navigator.pop(context);
                      },
                child: const Text('ADD TO CART',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
