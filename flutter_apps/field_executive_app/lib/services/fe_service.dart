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

  Future<FeProfile> updateMyProfile({String? fullName, String? email}) async {
    final payload = <String, dynamic>{};
    if (fullName != null) payload['full_name'] = fullName;
    if (email != null) payload['email'] = email;

    final response = await _apiClient.put('/api/v1/employees/me', payload);
    if (response.statusCode == 200) {
      return FeProfile.fromJson(jsonDecode(response.body));
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

  Future<List<VisitModel>> getVisits() async {
    final response = await _apiClient.get('/api/v1/visits');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => VisitModel.fromJson(j)).toList();
    }
    throw Exception('Failed to load visits: ${response.statusCode}');
  }

  Future<VisitModel> uploadVisitPhoto(int visitId, {required double lat, required double lng, required String photoPath, String? notes}) async {
    final response = await _apiClient.postMultipart(
      '/api/v1/visits/$visitId/upload-photo',
      {
        'photo_lat': lat.toString(),
        'photo_lng': lng.toString(),
        if (notes != null) 'notes': notes,
      },
      photoPath,
    );
    if (response.statusCode == 200) {
      return VisitModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
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

  Future<void> updateLocation(double lat, double lng, {double? accuracy, double? speed}) async {
    await _apiClient.post(
      '/api/v1/tracking/location',
      {
        'lat': lat,
        'lng': lng,
        if (accuracy != null) 'accuracy': accuracy,
        if (speed != null) 'speed': speed,
      },
    );
  }

  Future<void> submitEodReport(int completedVisits, int pendingVisits, int totalBagsOrdered, String? notes) async {
    final response = await _apiClient.post(
      '/api/v1/eod',
      {
        'completed_visits': completedVisits,
        'pending_visits': pendingVisits,
        'total_bags_ordered': totalBagsOrdered,
        if (notes != null) 'notes': notes,
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to submit EOD report: ${response.statusCode} - ${response.body}');
    }
  }
}
