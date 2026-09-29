import os

BASE_DIR = r"C:\Users\Acer\.gemini\antigravity\scratch\yadvi-seeds-app\flutter_apps\shop_owner_app\lib"

files = {
    "models/product.dart": """
class Product {
  final int id;
  final String name;
  final String varietyType;
  final String sku;
  final String category;
  final String imageUrl;
  final int availableStockBags;
  final String germinationRate;
  final String purity;
  final String maturityDays;
  final String cropSeason;
  final String availability;
  final String description;
  final List<String> packageSizes;

  Product({
    required this.id,
    required this.name,
    required this.varietyType,
    required this.sku,
    required this.category,
    required this.imageUrl,
    required this.availableStockBags,
    required this.germinationRate,
    required this.purity,
    required this.maturityDays,
    required this.cropSeason,
    required this.availability,
    required this.description,
    required this.packageSizes,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'] ?? '',
      varietyType: json['variety_type'] ?? '',
      sku: json['sku'] ?? '',
      category: json['category'] ?? '',
      imageUrl: json['image_url'] ?? '',
      availableStockBags: json['available_stock_bags'] ?? 0,
      germinationRate: json['germination_rate'] ?? '',
      purity: json['purity'] ?? '',
      maturityDays: json['maturity_days'] ?? '',
      cropSeason: json['crop_season'] ?? '',
      availability: json['availability'] ?? '',
      description: json['description'] ?? '',
      packageSizes: (json['package_sizes'] as String?)?.split(',').map((e) => e.trim()).toList() ?? [],
    );
  }
}
""",
    "models/order.dart": """
class OrderItem {
  final int productId;
  final String productName;
  final String sku;
  final String imageUrl;
  final String packageSize;
  final int quantityBags;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.imageUrl,
    required this.packageSize,
    required this.quantityBags,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['product_id'],
      productName: json['product_name'] ?? '',
      sku: json['sku'] ?? '',
      imageUrl: json['image_url'] ?? '',
      packageSize: json['package_size'] ?? '',
      quantityBags: json['quantity_bags'] ?? 0,
    );
  }
}

class Order {
  final int id;
  final String orderNumber;
  final String shopName;
  final String shopLocation;
  final String deliveryAddress;
  final int totalQuantityBags;
  final String status;
  final String? assignedExecutiveName;
  final String? lrNumber;
  final String? transporterName;
  final String createdAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.orderNumber,
    required this.shopName,
    required this.shopLocation,
    required this.deliveryAddress,
    required this.totalQuantityBags,
    required this.status,
    this.assignedExecutiveName,
    this.lrNumber,
    this.transporterName,
    required this.createdAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      orderNumber: json['order_number'] ?? '',
      shopName: json['shop_name'] ?? '',
      shopLocation: json['shop_location'] ?? '',
      deliveryAddress: json['delivery_address'] ?? '',
      totalQuantityBags: json['total_quantity_bags'] ?? 0,
      status: json['status'] ?? 'New',
      assignedExecutiveName: json['assigned_executive_name'],
      lrNumber: json['lr_number'],
      transporterName: json['transporter_name'],
      createdAt: json['created_at'] ?? '',
      items: (json['items'] as List?)?.map((i) => OrderItem.fromJson(i)).toList() ?? [],
    );
  }
}
""",
    "services/shop_service.dart": """
import 'dart:convert';
import '../core/network/api_client.dart';
import '../models/product.dart';
import '../models/order.dart';

class ShopService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Product>> getProducts() async {
    final response = await _apiClient.get('/api/v1/products');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => Product.fromJson(json)).toList();
    }
    throw Exception('Failed to load products');
  }

  Future<List<Order>> getOrders() async {
    final response = await _apiClient.get('/api/v1/orders');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => Order.fromJson(json)).toList();
    }
    throw Exception('Failed to load orders');
  }

  Future<Order> placeOrder(List<Map<String, dynamic>> items, String notes) async {
    final response = await _apiClient.post('/api/v1/orders', {
      'items': items,
      'delivery_notes': notes,
      'source': 'Shop Owner App'
    });
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to place order');
  }
}
""",
    "features/cart/cart_provider.dart": """
import 'package:flutter/material.dart';
import '../../models/product.dart';

class CartItem {
  final Product product;
  final String packageSize;
  int quantityBags;

  CartItem({required this.product, required this.packageSize, required this.quantityBags});
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  int get totalBags => _items.fold(0, (sum, item) => sum + item.quantityBags);

  void addItem(Product product, String packageSize, int quantity) {
    final existing = _items.where((i) => i.product.id == product.id && i.packageSize == packageSize).firstOrNull;
    if (existing != null) {
      existing.quantityBags += quantity;
    } else {
      _items.add(CartItem(product: product, packageSize: packageSize, quantityBags: quantity));
    }
    notifyListeners();
  }

  void updateQuantity(Product product, String packageSize, int newQuantity) {
    if (newQuantity <= 0) {
      _items.removeWhere((i) => i.product.id == product.id && i.packageSize == packageSize);
    } else {
      final existing = _items.where((i) => i.product.id == product.id && i.packageSize == packageSize).firstOrNull;
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
""",
    "features/dashboard/dashboard_screen.dart": """
import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../catalogue/catalogue_screen.dart';
import '../orders/my_orders_screen.dart';
import '../cart/cart_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final _authService = AuthService();

  final List<Widget> _screens = [
    const HomeTab(),
    const CatalogueScreen(),
    const MyOrdersScreen(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green[800],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'Catalogue'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
        backgroundColor: Colors.green[800],
        child: const Icon(Icons.shopping_cart, color: Colors.white),
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome to Yadvi', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('View the latest catalogue and place your orders.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildCard(context, 'Catalogue', Icons.local_florist, Colors.green),
                  _buildCard(context, 'My Orders', Icons.shopping_basket, Colors.blue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, IconData icon, MaterialColor color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Nav handling via bottom nav ideally, omitted here for simplicity
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () async {
          await AuthService().logout();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        icon: const Icon(Icons.logout),
        label: const Text('Logout'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
""",
    "features/catalogue/catalogue_screen.dart": """
import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/shop_service.dart';
import 'product_details_screen.dart';
import '../../config/app_config.dart';

class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({super.key});

  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  final _shopService = ShopService();
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _shopService.getProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Seed Catalogue')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _products.isEmpty
                    ? const Center(child: Text('No products available.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final p = _products[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              leading: Image.network('${AppConfig.apiBaseUrl}${p.imageUrl}', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 50)),
                              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('SKU: ${p.sku}\\nStock: ${p.availableStockBags} Bags'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: p)));
                              },
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
""",
    "features/catalogue/product_details_screen.dart": """
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../cart/cart_provider.dart';
import '../../config/app_config.dart';

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
            Center(child: Image.network('${AppConfig.apiBaseUrl}${p.imageUrl}', height: 200, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 100))),
            const SizedBox(height: 16),
            Text(p.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(p.varietyType, style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 16),
            _buildInfoRow('SKU', p.sku),
            _buildInfoRow('Category', p.category),
            _buildInfoRow('Stock', '${p.availableStockBags} Bags'),
            _buildInfoRow('Germination', p.germinationRate),
            _buildInfoRow('Purity', p.purity),
            _buildInfoRow('Maturity', p.maturityDays),
            const SizedBox(height: 16),
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(p.description),
            const SizedBox(height: 24),
            
            const Text('Package Size', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _selectedSize,
              isExpanded: true,
              items: p.packageSizes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _selectedSize = v),
            ),
            const SizedBox(height: 16),
            
            const Text('Quantity (Bags)', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                IconButton(onPressed: () => setState(() { if (_quantity > 1) _quantity--; }), icon: const Icon(Icons.remove_circle_outline)),
                Text('$_quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => setState(() => _quantity++), icon: const Icon(Icons.add_circle_outline)),
              ],
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _selectedSize == null ? null : () {
                  Provider.of<CartProvider>(context, listen: false).addItem(p, _selectedSize!, _quantity);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $_quantity bag(s) to cart')));
                  Navigator.pop(context);
                },
                child: const Text('ADD TO CART', style: TextStyle(fontWeight: FontWeight.bold)),
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
""",
    "features/cart/cart_screen.dart": """
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cart_provider.dart';
import '../../services/shop_service.dart';
import '../../config/app_config.dart';
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
                          leading: Image.network('${AppConfig.apiBaseUrl}${item.product.imageUrl}', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image)),
                          title: Text(item.product.name),
                          subtitle: Text('Size: ${item.packageSize}\\nQuantity: ${item.quantityBags} Bags'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => cart.updateQuantity(item.product, item.packageSize, 0),
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
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
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
                      Text('Total Bags: ${cart.totalBags}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: _isSubmitting ? null : () async {
                          setState(() => _isSubmitting = true);
                          try {
                            final items = cart.items.map((i) => {
                              'product_id': i.product.id,
                              'package_size': i.packageSize,
                              'quantity_bags': i.quantityBags,
                            }).toList();
                            await ShopService().placeOrder(items, _notesController.text);
                            cart.clearCart();
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Order Placed'),
                                  content: const Text('Your order has been placed successfully.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context); // Close dialog
                                        Navigator.pop(context); // Close cart
                                      },
                                      child: const Text('OK'),
                                    )
                                  ]
                                )
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          } finally {
                            if (mounted) setState(() => _isSubmitting = false);
                          }
                        },
                        child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('PLACE ORDER', style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                )
              ],
            ),
    );
  }
}
""",
    "features/orders/my_orders_screen.dart": """
import 'package:flutter/material.dart';
import '../../services/shop_service.dart';
import '../../models/order.dart';
import 'order_details_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final _shopService = ShopService();
  List<Order> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await _shopService.getOrders();
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _orders.isEmpty
                  ? const Center(child: Text('No orders found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final o = _orders[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(o.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Status: ${o.status}\\nBags: ${o.totalQuantityBags}\\nAssigned: ${o.assignedExecutiveName ?? 'Not Assigned'}'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: o)));
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
""",
    "features/orders/order_details_screen.dart": """
import 'package:flutter/material.dart';
import '../../models/order.dart';

class OrderDetailsScreen extends StatelessWidget {
  final Order order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(order.orderNumber)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('ORDER INFORMATION', [
              _buildRow('Order Number', order.orderNumber),
              _buildRow('Date', order.createdAt.substring(0, 10)),
              _buildRow('Status', order.status),
            ]),
            const SizedBox(height: 16),
            
            _buildSection('SHOP INFORMATION', [
              _buildRow('Shop Name', order.shopName),
              _buildRow('Location', order.shopLocation),
              _buildRow('Delivery Address', order.deliveryAddress),
            ]),
            const SizedBox(height: 16),

            _buildSection('ASSIGNMENT', [
              _buildRow('Field Executive', order.assignedExecutiveName ?? 'Not Assigned'),
            ]),
            const SizedBox(height: 16),

            if (order.lrNumber != null)
              _buildSection('SHIPMENT', [
                _buildRow('LR Number', order.lrNumber ?? ''),
                _buildRow('Transporter', order.transporterName ?? ''),
              ]),
            if (order.lrNumber != null) const SizedBox(height: 16),

            const Text('ITEMS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
            const Divider(),
            ...order.items.map((item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(item.productName),
                subtitle: Text('SKU: ${item.sku}\\nSize: ${item.packageSize}'),
                trailing: Text('${item.quantityBags} Bags', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
        const Divider(),
        ...children,
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
"""
}

for path, content in files.items():
    full_path = os.path.join(BASE_DIR, path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, 'w', encoding='utf-8') as f:
        f.write(content.strip())

print("Files generated successfully.")
