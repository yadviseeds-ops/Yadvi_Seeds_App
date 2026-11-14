import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../services/shop_service.dart';
import '../cart/cart_provider.dart';
import '../cart/cart_screen.dart';
import 'product_details_screen.dart';
import '../../core/config/app_config.dart';

class CatalogueScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const CatalogueScreen({super.key, this.onBack});

  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  final _shopService = ShopService();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Chilli', 'Okra', 'Dolichos', 'Pulses', 'Field Crops'];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _shopService.getProducts();
      if (mounted) {
        setState(() {
          _products = products;
          _filteredProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _filterProducts() {
    setState(() {
      _filteredProducts = _products.where((p) {
        final matchesCategory = _selectedCategory == 'All' || p.category == _selectedCategory;
        final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.sku.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text('Products', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cart, _) => IconButton(
              icon: Badge(
                isLabelVisible: cart.totalQuantityCount > 0,
                label: Text('${cart.totalQuantityCount}'),
                child: const Icon(Icons.shopping_cart_outlined, color: Colors.black87),
              ),
              tooltip: 'Shopping Cart',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search seed variety or SKU...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Colors.green, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Colors.green, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    _searchQuery = value;
                    _filterProducts();
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              _selectedCategory = category;
                              _filterProducts();
                            }
                          },
                          backgroundColor: Colors.white,
                          selectedColor: const Color(0xFF0F422C),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF0F422C) : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _filteredProducts.isEmpty
                        ? const Center(child: Text('No products found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, index) {
                              final p = _filteredProducts[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.green.shade200, width: 1),
                                ),
                                elevation: 0,
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProductDetailsScreen(product: p),
                                        ),
                                      );
                                    },
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            width: 100,
                                            height: 120,
                                            color: Colors.grey.shade100,
                                            child: p.imageUrl.isNotEmpty
                                                ? Image.network(
                                                    '${AppConfig.apiBaseUrl}${p.imageUrl}',
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 50, color: Colors.grey),
                                                  )
                                                : const Icon(Icons.image, size: 50, color: Colors.grey),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.shade50,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      p.sku,
                                                      style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  Text(
                                                    p.availability,
                                                    style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                p.name,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F422C)),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                p.description,
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Stock: ${p.availableStockKg.toStringAsFixed(p.availableStockKg.truncateToDouble() == p.availableStockKg ? 0 : 2)} kg',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                                  ),
                                                  ElevatedButton.icon(
                                                    onPressed: () {
                                                      final isOutOfStock = p.availability.toLowerCase().contains('out of stock') || p.availableStockKg <= 0;
                                                      if (isOutOfStock) {
                                                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(
                                                            content: Text('Product is currently out of stock'),
                                                            backgroundColor: Colors.redAccent,
                                                          ),
                                                        );
                                                        return;
                                                      }
                                                      final packageSize = p.packageSizes.isNotEmpty ? p.packageSizes.first : 'Standard';
                                                      Provider.of<CartProvider>(context, listen: false).addItem(p, packageSize, 1.0, unit: 'kg');
                                                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text('Product added to cart: ${p.name} (1 kg)'),
                                                          backgroundColor: const Color(0xFF2E7D32),
                                                          duration: const Duration(seconds: 2),
                                                        ),
                                                      );
                                                    },
                                                    icon: const Icon(Icons.add, size: 16),
                                                    label: const Text('Add to Cart'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF0F422C),
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                      elevation: 0,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
