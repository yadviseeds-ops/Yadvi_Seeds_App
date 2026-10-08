import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../core/network/api_client.dart';
import '../models/fe_profile.dart';
import '../models/visit_model.dart';
import '../models/order_model.dart';
import '../models/shipment_model.dart';

class FeService {
  final ApiClient _apiClient = ApiClient();
  static Timer? _dailyGpsTimer;
  static bool _isGpsActive = false;

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
    print('Starting FE Daily GPS tracking (Background Service)...');
    
    // Request permissions in foreground first
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services disabled.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        print('Location permissions denied.');
        return;
      }
    }

    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
    
    _isGpsActive = true;
  }

  void stopDailyGps() {
    print('Stopping FE Daily GPS tracking (Background Service)...');
    final service = FlutterBackgroundService();
    service.invoke('stopService');
    _isGpsActive = false;
  }
}
