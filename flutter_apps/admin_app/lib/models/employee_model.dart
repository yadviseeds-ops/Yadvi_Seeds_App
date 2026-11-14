class AssignedShopModel {
  final int id;
  final String shopName;
  final String marketLocation;
  final String address;
  final String status;
  final String? phone;
  final String? ownerName;

  AssignedShopModel({
    required this.id,
    required this.shopName,
    required this.marketLocation,
    required this.address,
    required this.status,
    this.phone,
    this.ownerName,
  });

  factory AssignedShopModel.fromJson(Map<String, dynamic> json) {
    return AssignedShopModel(
      id: json['id'] ?? 0,
      shopName: json['shop_name']?.toString() ?? '',
      marketLocation: json['market_location']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
      phone: json['phone']?.toString(),
      ownerName: json['owner_name']?.toString(),
    );
  }
}

class EmployeeModel {
  final int id;
  final int userId;
  final String username;
  final String employeeCode;
  final String designation;
  final String assignedTerritory;
  final double? currentLat;
  final double? currentLng;
  final int batteryLevel;
  final String attendanceStatus;
  final double distanceCoveredKm;
  final DateTime? lastLocationUpdate;
  final String fullName;
  final String phone;
  final String? email;
  final bool isActive;
  final List<AssignedShopModel> assignedShops;
  final int totalAssignedShops;
  final int completedVisits;
  final int pendingVisits;

  EmployeeModel({
    required this.id,
    required this.userId,
    this.username = '',
    required this.employeeCode,
    required this.designation,
    required this.assignedTerritory,
    this.currentLat,
    this.currentLng,
    required this.batteryLevel,
    required this.attendanceStatus,
    required this.distanceCoveredKm,
    this.lastLocationUpdate,
    required this.fullName,
    required this.phone,
    this.email,
    required this.isActive,
    this.assignedShops = const [],
    this.totalAssignedShops = 0,
    this.completedVisits = 0,
    this.pendingVisits = 0,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    DateTime? lastUpdate;
    if (json['last_location_update'] != null) {
      try {
        lastUpdate = DateTime.parse(json['last_location_update'].toString());
      } catch (_) {}
    }

    final shopsRaw = json['assigned_shops'] as List?;
    final shops = shopsRaw != null
        ? shopsRaw.map((s) => AssignedShopModel.fromJson(Map<String, dynamic>.from(s as Map))).toList()
        : <AssignedShopModel>[];

    return EmployeeModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      username: json['username']?.toString() ?? '',
      employeeCode: json['employee_code']?.toString() ?? '',
      designation: (json['designation'] == null || json['designation'] == '' || json['designation'] == 'Field Sales Officer') ? 'Field Executive' : json['designation'].toString(),
      assignedTerritory: json['assigned_territory']?.toString() ?? '',
      currentLat: (json['current_lat'] as num?)?.toDouble(),
      currentLng: (json['current_lng'] as num?)?.toDouble(),
      batteryLevel: json['battery_level'] ?? 0,
      attendanceStatus: json['attendance_status']?.toString() ?? 'Absent',
      distanceCoveredKm: (json['distance_covered_km'] as num?)?.toDouble() ?? 0.0,
      lastLocationUpdate: lastUpdate,
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      isActive: json['is_active'] ?? true,
      assignedShops: shops,
      totalAssignedShops: json['total_assigned_shops'] ?? shops.length,
      completedVisits: json['completed_visits'] ?? 0,
      pendingVisits: json['pending_visits'] ?? 0,
    );
  }

  EmployeeModel copyWith({
    int? id,
    int? userId,
    String? username,
    String? employeeCode,
    String? designation,
    String? assignedTerritory,
    double? currentLat,
    double? currentLng,
    int? batteryLevel,
    String? attendanceStatus,
    double? distanceCoveredKm,
    DateTime? lastLocationUpdate,
    String? fullName,
    String? phone,
    String? email,
    bool? isActive,
    List<AssignedShopModel>? assignedShops,
    int? totalAssignedShops,
    int? completedVisits,
    int? pendingVisits,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      employeeCode: employeeCode ?? this.employeeCode,
      designation: designation ?? this.designation,
      assignedTerritory: assignedTerritory ?? this.assignedTerritory,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      distanceCoveredKm: distanceCoveredKm ?? this.distanceCoveredKm,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      assignedShops: assignedShops ?? this.assignedShops,
      totalAssignedShops: totalAssignedShops ?? this.totalAssignedShops,
      completedVisits: completedVisits ?? this.completedVisits,
      pendingVisits: pendingVisits ?? this.pendingVisits,
    );
  }
}
