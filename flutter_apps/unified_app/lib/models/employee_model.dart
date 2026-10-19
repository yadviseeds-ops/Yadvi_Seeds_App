class EmployeeModel {
  final int id;
  final int userId;
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

  EmployeeModel({
    required this.id,
    required this.userId,
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
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    DateTime? lastUpdate;
    if (json['last_location_update'] != null) {
      try {
        lastUpdate = DateTime.parse(json['last_location_update'].toString());
      } catch (_) {}
    }

    return EmployeeModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      employeeCode: json['employee_code']?.toString() ?? '',
      designation: json['designation']?.toString() ?? 'Field Sales Officer',
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
    );
  }

  EmployeeModel copyWith({
    int? id,
    int? userId,
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
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
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
    );
  }
}
