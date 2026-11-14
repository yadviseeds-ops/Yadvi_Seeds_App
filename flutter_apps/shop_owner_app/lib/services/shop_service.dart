import 'dart:convert';
import '../core/network/api_client.dart';
import '../models/product.dart';
import '../models/order.dart';

class ShopService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getMyProfile() async {
    final response = await _apiClient.get('/api/v1/shops/my');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load profile: ');
  }

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

  Future<Order> placeOrder(
      List<Map<String, dynamic>> items, String notes) async {
    final response = await _apiClient.post('/api/v1/orders',
        {'items': items, 'delivery_notes': notes, 'source': 'Shop Owner App'});

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to place order: ${response.statusCode} - ${response.body}');
  }

  Future<Map<String, dynamic>> updateProfile({
    String? ownerName,
    String? shopName,
    String? email,
    String? address,
    String? marketLocation,
  }) async {
    final payload = <String, dynamic>{};
    if (ownerName != null) payload['owner_name'] = ownerName;
    if (shopName != null) payload['shop_name'] = shopName;
    if (email != null) payload['email'] = email;
    if (address != null) payload['address'] = address;
    if (marketLocation != null) payload['market_location'] = marketLocation;

    final response = await _apiClient.put('/api/v1/shops/my', payload);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    String msg = 'Failed to update profile (${response.statusCode})';
    try {
      final err = jsonDecode(response.body);
      if (err is Map && err['detail'] != null) {
        msg = err['detail'].toString();
      }
    } catch (_) {}
    throw Exception(msg);
  }
}
