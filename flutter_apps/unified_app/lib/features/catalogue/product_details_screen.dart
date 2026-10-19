import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unified_app/models/product.dart';
import 'package:unified_app/features/cart/cart_provider.dart';
import 'package:unified_app/core/config/app_config.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final TextEditingController _quantityController = TextEditingController(text: '1');
  String _selectedUnit = 'kg';
  String? _selectedPackageSize;

  @override
  void initState() {
    super.initState();
    if (widget.product.packageSizes.isNotEmpty) {
      _selectedPackageSize = widget.product.packageSizes.first;
    } else {
      _selectedPackageSize = 'Standard';
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  double get _currentQuantity {
    final text = _quantityController.text.trim();
    return double.tryParse(text) ?? 0.0;
  }

  double get _currentQuantityKg {
    final qty = _currentQuantity;
    return _selectedUnit.toLowerCase() == 'g' ? qty / 1000.0 : qty;
  }

  void _stepQuantity(double delta) {
    double current = _currentQuantity;
    double newQty;
    if (_selectedUnit == 'kg') {
      newQty = (current + delta);
      if (newQty < 0.1) newQty = 0.1;
      newQty = (newQty * 10).round() / 10;
      _quantityController.text = newQty.truncateToDouble() == newQty ? newQty.toInt().toString() : newQty.toString();
    } else {
      final gramDelta = (delta * 100).round();
      newQty = (current + gramDelta);
      if (newQty < 50) newQty = 50;
      _quantityController.text = newQty.toInt().toString();
    }
    setState(() {});
  }

  void _onUnitChanged(String newUnit) {
    if (newUnit == _selectedUnit) return;
    final current = _currentQuantity;
    setState(() {
      _selectedUnit = newUnit;
      if (newUnit == 'g') {
        final grams = (current * 1000).round();
        _quantityController.text = grams > 0 ? grams.toString() : '500';
      } else {
        final kg = current / 1000.0;
        final roundedKg = (kg * 100).round() / 100;
        _quantityController.text = roundedKg > 0 ? (roundedKg.truncateToDouble() == roundedKg ? roundedKg.toInt().toString() : roundedKg.toString()) : '1';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isOutOfStock = p.availableStockKg <= 0;
    final stockExceeded = !isOutOfStock && _currentQuantityKg > p.availableStockKg;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F5),
      appBar: AppBar(
        title: Text(p.name, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF4F6F5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: p.imageUrl.isNotEmpty
                      ? Image.network(
                          p.imageUrl.startsWith('/') ? '${AppConfig.apiBaseUrl}${p.imageUrl}' : p.imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.eco, size: 80, color: Color(0xFF2E7D32)),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.eco, size: 80, color: Color(0xFF2E7D32)),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.varietyType,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isOutOfStock ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isOutOfStock ? Colors.red.shade300 : Colors.green.shade300),
                  ),
                  child: Text(
                    isOutOfStock ? 'Out of Stock' : '${p.availableStockKg.toStringAsFixed(p.availableStockKg.truncateToDouble() == p.availableStockKg ? 0 : 2)} kg Available',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOutOfStock ? Colors.red.shade800 : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow('SKU Code', p.sku.isNotEmpty ? p.sku : 'N/A'),
            _buildInfoRow('Category', p.category),
            _buildInfoRow('Available Stock', '${p.availableStockKg.toStringAsFixed(p.availableStockKg.truncateToDouble() == p.availableStockKg ? 0 : 2)} kg'),
            if (p.germinationRate.isNotEmpty) _buildInfoRow('Germination Rate', p.germinationRate),
            if (p.purity.isNotEmpty) _buildInfoRow('Genetic Purity', p.purity),
            if (p.maturityDays.isNotEmpty) _buildInfoRow('Maturity Period', p.maturityDays),
            if (p.cropSeason.isNotEmpty) _buildInfoRow('Recommended Season', p.cropSeason),
            if (p.packageSizes.isNotEmpty) _buildInfoRow('Available Pack Sizes', p.packageSizes.join(', ')),

            if (p.description.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 6),
              Text(
                p.description,
                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
              ),
            ],

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            // Packaging Selection
            if (p.packageSizes.isNotEmpty) ...[
              const Text(
                'Select Packaging',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: p.packageSizes.map((size) {
                  final isSelected = _selectedPackageSize == size;
                  return ChoiceChip(
                    label: Text(size),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF2E7D32) : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedPackageSize = size);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Order Quantity Section (g / kg)
            const Text(
              'Order Quantity (Weight)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              'Specify exact weight in grams (g) or kilograms (kg)',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.remove, color: Colors.black87),
                    onPressed: () => _stepQuantity(-1.0),
                    tooltip: 'Decrease quantity',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    onChanged: (v) => setState(() {}),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Quantity',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.black87),
                    onPressed: () => _stepQuantity(1.0),
                    tooltip: 'Increase quantity',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedUnit,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2E7D32)),
                        items: const [
                          DropdownMenuItem(
                            value: 'kg',
                            child: Text('kg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          DropdownMenuItem(
                            value: 'g',
                            child: Text('g', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) _onUnitChanged(v);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedUnit == 'g' && _currentQuantity > 0)
              Text(
                'Total weight: ${(_currentQuantity / 1000.0).toStringAsFixed(3)} kg',
                style: const TextStyle(fontSize: 13, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
              ),

            if (stockExceeded)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Warning: Requested quantity (${_currentQuantityKg.toStringAsFixed(2)} kg) exceeds available stock (${p.availableStockKg} kg).',
                  style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isOutOfStock || stockExceeded) ? Colors.grey : const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                onPressed: (isOutOfStock || stockExceeded)
                    ? null
                    : () {
                        final qty = _currentQuantity;
                        if (qty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid positive quantity')),
                          );
                          return;
                        }

                        final qtyKg = _currentQuantityKg;
                        if (qtyKg > p.availableStockKg) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Cannot order more than available stock (${p.availableStockKg} kg)'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        final packageSize = _selectedPackageSize ?? 'Standard';
                        Provider.of<CartProvider>(context, listen: false).addItem(
                          p,
                          packageSize,
                          qty,
                          unit: _selectedUnit,
                        );

                        final displayQty = qty.truncateToDouble() == qty ? qty.toInt().toString() : qty.toString();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added $displayQty $_selectedUnit of ${p.name} to cart'),
                            backgroundColor: const Color(0xFF2E7D32),
                          ),
                        );
                        Navigator.pop(context);
                      },
                child: Text(
                  isOutOfStock ? 'OUT OF STOCK' : 'ADD TO CART',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
