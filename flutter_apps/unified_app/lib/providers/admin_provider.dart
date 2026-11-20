import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/network/api_client.dart';
import '../models/dashboard_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/employee_model.dart';
import '../models/shop_model.dart';
import '../models/attendance_model.dart';
import '../models/visit_model.dart';
import '../models/shipment_model.dart';
import '../models/eod_model.dart';

class AdminProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  // Loading flags
  bool _isLoadingDashboard = false;
  bool _isLoadingOrders = false;
  bool _isLoadingProducts = false;
  bool _isLoadingEmployees = false;
  bool _isLoadingShops = false;
  bool _isLoadingAttendance = false;
  bool _isLoadingVisits = false;
  bool _isLoadingShipments = false;
  bool _isLoadingEod = false;

  // Error messages
  String? _error;

  // Data state
  DashboardDataModel? _dashboardData;
  List<OrderModel> _orders = [];
  List<ProductModel> _products = [];
  List<EmployeeModel> _employees = [];
  List<ShopModel> _shops = [];
  List<AttendanceModel> _attendance = [];
  List<VisitModel> _visits = [];
  List<ShipmentModel> _shipments = [];
  List<EODReportModel> _eodReports = [];

  // Getters
  bool get isLoadingDashboard => _isLoadingDashboard;
  bool get isLoadingOrders => _isLoadingOrders;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isLoadingEmployees => _isLoadingEmployees;
  bool get isLoadingShops => _isLoadingShops;
  bool get isLoadingAttendance => _isLoadingAttendance;
  bool get isLoadingVisits => _isLoadingVisits;
  bool get isLoadingShipments => _isLoadingShipments;
  bool get isLoadingEod => _isLoadingEod;
  String? get error => _error;

  DashboardDataModel? get dashboardData => _dashboardData;
  List<OrderModel> get orders => _orders;
  List<ProductModel> get products => _products;
  List<EmployeeModel> get employees => _employees;
  List<ShopModel> get shops => _shops;
  List<AttendanceModel> get attendance => _attendance;
  List<VisitModel> get visits => _visits;
  List<ShipmentModel> get shipments => _shipments;
  List<EODReportModel> get eodReports => _eodReports;

  @visibleForTesting
  void setVisitsForTesting(List<VisitModel> v) {
    _visits = v;
  }

  // 1. Fetch Dashboard
  Future<void> fetchDashboard() async {
    _isLoadingDashboard = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _apiClient.get('/api/v1/dashboard/admin');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _dashboardData = DashboardDataModel.fromJson(data);
      } else {
        _error = 'Failed to load dashboard (${res.statusCode})';
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingDashboard = false;
      notifyListeners();
    }
  }

  // 2. Orders
  Future<void> fetchOrders() async {
    _isLoadingOrders = true;
    notifyListeners();

    try {
      final res = await _apiClient.get('/api/v1/orders');
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        _orders = data.map((item) => OrderModel.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('[AdminProvider] Error loading orders: $e');
    } finally {
      _isLoadingOrders = false;
      notifyListeners();
    }
  }

  Future<bool> updateOrderStatus(
    int orderId,
    String newStatus, {
    String? lrNumber,
    String? transporter,
  }) async {
    try {
      final payload = <String, dynamic>{'status': newStatus};
      if (lrNumber != null) payload['lr_number'] = lrNumber;
      if (transporter != null) payload['transporter_name'] = transporter;

      final res = await _apiClient.put(
        '/api/v1/orders/$orderId/status',
        payload,
      );
      if (res.statusCode == 200) {
        await fetchOrders();
        await fetchDashboard();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AdminProvider] Error updating order status: $e');
      return false;
    }
  }

  Future<bool> assignOrderExecutive(int orderId, int executiveId) async {
    try {
      final res = await _apiClient.put(
        '/api/v1/orders/$orderId/assign-executive',
        {'executive_id': executiveId},
      );
      if (res.statusCode == 200) {
        await fetchOrders();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AdminProvider] Error assigning order executive: $e');
      return false;
    }
  }

  // 3. Products
  Future<void> fetchProducts() async {
    _isLoadingProducts = true;
    notifyListeners();

    try {
      final res = await _apiClient.get('/api/v1/products');
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        _products = data.map((item) => ProductModel.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('[AdminProvider] Error loading products: $e');
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  String _extractErrorMessage(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        if (body['detail'] != null) {
          if (body['detail'] is String) return body['detail'];
          if (body['detail'] is List) {
            return (body['detail'] as List)
                .map(
                  (e) => e is Map ? (e['msg'] ?? e.toString()) : e.toString(),
                )
                .join(', ');
          }
        }
        if (body['message'] != null) return body['message'].toString();
      }
    } catch (_) {}
    return 'Server error (HTTP ${res.statusCode})';
  }

  Future<String?> uploadProductImage(List<int> bytes, String filename) async {
    try {
      final res = await _apiClient.postMultipartBytes(
        '/api/v1/products/upload-image',
        bytes,
        filename,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data['image_url'] as String?;
      }
      debugPrint(
        '[AdminProvider] Upload image failed: ${res.statusCode} ${res.body}',
      );
      return null;
    } catch (e) {
      debugPrint('[AdminProvider] Error uploading product image: $e');
      return null;
    }
  }

  Future<String?> createProductWithResult(Map<String, dynamic> payload) async {
    try {
      final res = await _apiClient.post('/api/v1/products', payload);
      if (res.statusCode == 200 || res.statusCode == 201) {
        await fetchProducts();
        await fetchDashboard();
        return null;
      }
      return _extractErrorMessage(res);
    } catch (e) {
      debugPrint('[AdminProvider] Error creating product: $e');
      return e.toString();
    }
  }

  Future<String?> updateProductWithResult(
    int productId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _apiClient.put('/api/v1/products/$productId', payload);
      if (res.statusCode == 200) {
        await fetchProducts();
        await fetchDashboard();
        return null;
      }
      return _extractErrorMessage(res);
    } catch (e) {
      debugPrint('[AdminProvider] Error updating product: $e');
      return e.toString();
    }
  }

  Future<bool> createProduct(Map<String, dynamic> payload) async {
    final err = await createProductWithResult(payload);
    return err == null;
  }

  Future<String?> deleteProduct(int productId) async {
    try {
      final res = await _apiClient.delete('/api/v1/products/$productId');
      if (res.statusCode == 200 || res.statusCode == 204) {
        await fetchProducts();
        await fetchDashboard();
        return null;
      }
      return _extractErrorMessage(res);
    } catch (e) {
      debugPrint('[AdminProvider] Error deleting product: $e');
      return 'Network error: $e';
    }
  }

  // 4. Employees
  Future<void> fetchEmployees() async {
    _isLoadingEmployees = true;
    notifyListeners();

    try {
      final res = await _apiClient.get('/api/v1/employees');
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        _employees = data.map((item) => EmployeeModel.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('[AdminProvider] Error loading employees: $e');
    } finally {
      _isLoadingEmployees = false;
      notifyListeners();
    }
  }

  Future<EmployeeModel?> fetchEmployeeDetails(int employeeId) async {
    try {
      final res = await _apiClient.get('/api/v1/employees/$employeeId');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final emp = EmployeeModel.fromJson(data);
        final index = _employees.indexWhere((e) => e.id == employeeId);
        if (index != -1) {
          if (!emp.isActive) {
            _employees.removeAt(index);
          } else {
            _employees[index] = emp;
          }
        } else if (emp.isActive) {
          _employees.add(emp);
        }
        notifyListeners();
        return emp;
      }
    } catch (e) {
      debugPrint('[AdminProvider] Error loading employee details: $e');
    }
    // Fallback to local cache if present
    final matches = _employees.where((e) => e.id == employeeId);
    if (matches.isNotEmpty) {
      return matches.first;
    }
    return null;
  }

  void updateEmployeeLocation(
    int employeeId,
    double lat,
    double lng,
    int battery,
    DateTime lastUpdate,
  ) {
    final index = _employees.indexWhere((e) => e.id == employeeId);
    if (index != -1) {
      _employees[index] = _employees[index].copyWith(
        currentLat: lat,
        currentLng: lng,
        batteryLevel: battery,
        lastLocationUpdate: lastUpdate,
      );
      notifyListeners();
    }
  }

  Future<String?> createEmployee(Map<String, dynamic> payload) async {
    try {
      final res = await _apiClient.post('/api/v1/employees', payload);
      if (res.statusCode == 200 || res.statusCode == 201) {
        await fetchEmployees();
        await fetchDashboard();
        return null;
      }
      try {
        final data = jsonDecode(res.body);
        if (data is Map && data['detail'] != null) {
          return data['detail'].toString();
        }
      } catch (_) {}
      return 'Failed to add executive (HTTP ${res.statusCode})';
    } catch (e) {
      debugPrint('[AdminProvider] Error creating employee: $e');
      return 'Network error: $e';
    }
  }

  Future<String?> updateEmployee(int employeeId, Map<String, dynamic> payload) async {
    try {
      final res = await _apiClient.put('/api/v1/employees/$employeeId', payload);
      if (res.statusCode == 200) {
        await fetchEmployees();
        await fetchEmployeeDetails(employeeId);
        return null;
      }
      return _extractErrorMessage(res);
    } catch (e) {
      debugPrint('[AdminProvider] Error updating employee: $e');
      return 'Network error: $e';
    }
  }

  Future<String?> deleteEmployee(int employeeId) async {
    try {
      final res = await _apiClient.delete('/api/v1/employees/$employeeId');
      if (res.statusCode == 200 || res.statusCode == 204) {
        await fetchEmployees();
        await fetchDashboard();
        return null;
      }
      return _extractErrorMessage(res);
    } catch (e) {
      debugPrint('[AdminProvider] Error deleting employee: $e');
      return 'Network error: $e';
    }
  }

  // 5. Shops
  Future<void> fetchShops() async {
    _isLoadingShops = true;
    notifyListeners();

    try {
      final res = await _apiClient.get('/api/v1/shops');
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        _shops = data.map((item) => ShopModel.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('[AdminProvider] Error loading shops: $e');
    } finally {
      _isLoadingShops = false;
      notifyListeners();
    }
  }

  Future<String?> createShop(Map<String, dynamic> payload) async {
    try {
      final res = await _apiClient.post('/api/v1/shops', payload);
      if (res.statusCode == 200 || res.statusCode == 201) {
        await fetchShops();
        await fetchDashboard();
        return null;
      }
      try {
        final data = jsonDecode(res.body);
        if (data is Map && data['detail'] != null) {
          return data['detail'].toString();
        }
      } catch (_) {}
      return 'Failed to add shop owner (HTTP ${res.statusCode})';
    } catch (e) {
      debugPrint('[AdminProvider] Error creating shop: $e');
      return 'Network error: $e';
    }
  }

  Future<bool> assignShop(int shopId, int? executiveId) async {
    try {
      final res = await _apiClient.put('/api/v1/shops/$shopId/assign', {
        'executive_id': executiveId,
      });
      if (res.statusCode == 200) {
        await fetchShops();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AdminProvider] Error assigning shop: $e');
      return false;
    }
  }

  Future<String?> updateShop(int shopId, Map<String, dynamic> payload) async {
    try {
      final res = await _apiClient.put('/api/v1/shops/$shopId', payload);
      if (res.statusCode == 200) {
        await fetchShops();
        return null;
      }
      return _extractErrorMessage(res);
    } catch (e) {
      debugPrint('[AdminProvider] Error updating shop: $e');
      return 'Network error: $e';
    }
  }

  Future<String?> updateShopFinancials(int shopId, {double? debtTaken, double? debtRepaid}) async {
    try {
      final payload = <String, dynamic>{};
      if (debtTaken != null) payload['debt_taken'] = debtTaken;
      if (debtRepaid != null) payload['debt_repaid'] = debtRepaid;

      final res = await _apiClient.put('/api/v1/shops/$shopId/financials', payload);
      if (res.statusCode == 200) {
        await fetchShops();
        return null;
      }
      return _extractErrorMessage(res);
    } catch (e) {
      debugPrint('[AdminProvider] Error updating shop financials: $e');
      return 'Network error: $e';
    }
  }

  Future<String?> deleteShop(int shopId) async {
    try {
      final res = await _apiClient.delete('/api/v1/shops/$shopId');
      if (res.statusCode == 200 || res.statusCode == 204) {
        await fetchShops();
        await fetchDashboard();
        return null;
      }
      return _extractErrorMessage(res);
    } catch (e) {
      debugPrint('[AdminProvider] Error deleting shop: $e');
      return 'Network error: $e';
    }
  }

  // 6. Attendance
  Future<void> fetchAttendance() async {
    _isLoadingAttendance = true;
    notifyListeners();

    try {
      final res = await _apiClient.get('/api/v1/attendance');
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        _attendance = data
            .map((item) => AttendanceModel.fromJson(item))
            .toList();
      }
    } catch (e) {
      debugPrint('[AdminProvider] Error loading attendance: $e');
    } finally {
      _isLoadingAttendance = false;
      notifyListeners();
    }
  }

  // 7. Visits
  String? _visitsError;
  String? get visitsError => _visitsError;

  Future<void> fetchVisits({int? executiveId}) async {
    _isLoadingVisits = true;
    _visitsError = null;
    notifyListeners();

    try {
      final endpoint = executiveId != null
          ? '/api/v1/visits?executive_id=$executiveId'
          : '/api/v1/visits';
      final res = await _apiClient.get(endpoint);
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        final fetched = data.map((item) => VisitModel.fromJson(item)).toList();
        if (executiveId != null) {
          _visits.removeWhere((v) => v.executiveId == executiveId);
          _visits.addAll(fetched);
        } else {
          _visits = fetched;
        }
      } else {
        _visitsError = 'Server returned status ${res.statusCode}';
      }
    } catch (e) {
      debugPrint('[AdminProvider] Error loading visits: $e');
      _visitsError = e.toString();
    } finally {
      _isLoadingVisits = false;
      notifyListeners();
    }
  }

  List<VisitModel> getVisitsForEodReport(EODReportModel report) {
    return _visits.where((v) {
      if (v.executiveId != report.executiveId) return false;
      final reportDate = report.reportDate.toLocal();
      final sched = v.scheduledDate.toLocal();
      final matchScheduled = sched.year == reportDate.year &&
          sched.month == reportDate.month &&
          sched.day == reportDate.day;
      final visited = v.visitedAt?.toLocal();
      final matchVisited = visited != null &&
          visited.year == reportDate.year &&
          visited.month == reportDate.month &&
          visited.day == reportDate.day;
      return matchScheduled || matchVisited;
    }).toList();
  }

  // 8. Shipments
  Future<void> fetchShipments() async {
    _isLoadingShipments = true;
    notifyListeners();

    try {
      final res = await _apiClient.get('/api/v1/shipments');
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        _shipments = data.map((item) => ShipmentModel.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('[AdminProvider] Error loading shipments: $e');
    } finally {
      _isLoadingShipments = false;
      notifyListeners();
    }
  }

  // 9. EOD Reports
  Future<void> fetchEodReports({DateTime? date}) async {
    _isLoadingEod = true;
    notifyListeners();

    try {
      String endpoint = '/api/v1/eod';
      if (date != null) {
        final dateStr =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        endpoint = '/api/v1/eod?date=$dateStr';
      }
      final res = await _apiClient.get(endpoint);
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        _eodReports = data
            .map((item) => EODReportModel.fromJson(item))
            .toList();
      }
    } catch (e) {
      debugPrint('[AdminProvider] Error loading EOD reports: $e');
    } finally {
      _isLoadingEod = false;
      notifyListeners();
    }
  }

  // Refresh all primary screens
  Future<void> refreshAll() async {
    await Future.wait([
      fetchDashboard(),
      fetchOrders(),
      fetchProducts(),
      fetchEmployees(),
      fetchShops(),
    ]);
  }
}
