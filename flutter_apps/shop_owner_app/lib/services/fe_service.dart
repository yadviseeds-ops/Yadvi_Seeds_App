import 'dart:convert';
import '../core/network/api_client.dart';
import '../models/fe_profile.dart';
import '../models/visit_model.dart';
import '../models/order_model.dart';
import '../models/shipment_model.dart';

class FeService {
  final ApiClient _apiClient = ApiClient();

  Future<FeProfile> getMyProfile() async {
    final response = await _apiClient.get('/api/v1/employees/me');
    if (response.statusCode == 200) {
      return FeProfile.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load profile: ${response.statusCode}');
  }

  Future<List<VisitModel>> getVisits() async {
    final response = await _apiClient.get('/api/v1/visits');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => VisitModel.fromJson(j)).toList();
    }
    throw Exception('Failed to load visits: ${response.statusCode}');
  }

  Future<VisitModel> checkInVisit(int visitId, {String? notes}) async {
    final response = await _apiClient.post(
      '/api/v1/visits/$visitId/checkin',
      {'notes': notes ?? ''},
    );
    if (response.statusCode == 200) {
      return VisitModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Check-in failed: ${response.body}');
  }

  Future<VisitModel> checkOutVisit(int visitId, {String? notes, int bagsOrdered = 0}) async {
    final response = await _apiClient.post(
      '/api/v1/visits/$visitId/checkout',
      {'notes': notes ?? '', 'bags_ordered': bagsOrdered},
    );
    if (response.statusCode == 200) {
      return VisitModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Check-out failed: ${response.body}');
  }

  Future<List<OrderModel>> getMyOrders() async {
    final response = await _apiClient.get('/api/v1/orders');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => OrderModel.fromJson(j)).toList();
    }
    throw Exception('Failed to load orders: ${response.statusCode}');
  }

  Future<List<ShipmentModel>> getMyShipments() async {
    final response = await _apiClient.get('/api/v1/shipments/my');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => ShipmentModel.fromJson(j)).toList();
    }
    throw Exception('Failed to load shipments: ${response.statusCode}');
  }

  Future<void> updateLocation(int employeeId, double lat, double lng, {int? battery}) async {
    await _apiClient.put(
      '/api/v1/employees/$employeeId/location',
      {
        'lat': lat,
        'lng': lng,
        if (battery != null) 'battery_level': battery,
      },
    );
  }

  Future<int> startTracking(int shipmentId) async {
    final response = await _apiClient.post(
      '/api/v1/tracking/start',
      {'shipment_id': shipmentId},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['session_id'] as int;
    }
    throw Exception('Failed to start tracking: ${response.body}');
  }

  Future<void> sendTrackingLocation(
    int sessionId,
    double lat,
    double lng,
    double accuracy,
    double speed,
  ) async {
    final response = await _apiClient.post(
      '/api/v1/tracking/location',
      {
        'session_id': sessionId,
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'speed': speed,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to send tracking location: ${response.body}');
    }
  }

  Future<void> stopTracking(int sessionId) async {
    final response = await _apiClient.post(
      '/api/v1/tracking/stop',
      {'session_id': sessionId},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to stop tracking: ${response.body}');
    }
  }
}
