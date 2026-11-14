import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../core/network/api_client.dart';
import '../models/fe_profile.dart';
import '../models/visit_model.dart';
import '../models/order_model.dart';
import '../models/shipment_model.dart';
import '../models/shop_model.dart';

class FeService {
  final ApiClient _apiClient = ApiClient();
  static bool _isGpsActive = false;

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

  Future<List<ShopModel>> getShops({bool allShops = true}) async {
    final response = await _apiClient.get('/api/v1/shops${allShops ? '?all_shops=true' : ''}');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => ShopModel.fromJson(j)).toList();
    }
    throw Exception('Failed to load shops: ${response.statusCode}');
  }

  Future<VisitModel> createPlannedVisit({
    required int shopId,
    String? purpose,
    String? notes,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/visits',
      {
        'shop_id': shopId,
        if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    if (response.statusCode == 200) {
      return VisitModel.fromJson(jsonDecode(response.body));
    }
    try {
      final errorData = jsonDecode(response.body);
      final detail = errorData['detail'] ?? 'Failed to add visit plan';
      throw Exception(detail);
    } catch (e) {
      if (e is Exception && !e.toString().contains('FormatException')) {
        rethrow;
      }
      throw Exception('Failed to add visit plan: ${response.statusCode}');
    }
  }

  Future<void> submitEodReport({
    required int completedVisits,
    required int pendingVisits,
    required int totalBagsOrdered,
    String? notes,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/eod',
      {
        'completed_visits': completedVisits,
        'pending_visits': pendingVisits,
        'total_bags_ordered': totalBagsOrdered,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    if (response.statusCode != 200) {
      try {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to submit EOD report: ${response.statusCode}');
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) rethrow;
        throw Exception('Failed to submit EOD report: ${response.statusCode}');
      }
    }
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

  Future<void> startDailyGps() async {
    if (_isGpsActive) return;

    // Request permissions in foreground first
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
    }

    try {
      final service = FlutterBackgroundService();
      bool isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
      }
    } catch (_) {
      // Background service supported on mobile platforms
    }

    _isGpsActive = true;
  }

  void stopDailyGps() {
    if (!_isGpsActive) return;
    try {
      final service = FlutterBackgroundService();
      service.invoke('stopService');
    } catch (_) {
      // Ignored on unsupported platforms or during testing
    }
    _isGpsActive = false;
  }
}
