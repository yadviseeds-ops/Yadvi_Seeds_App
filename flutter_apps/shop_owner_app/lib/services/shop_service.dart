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