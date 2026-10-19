// Models for Field Executive app

// fe_profile.dart
class FeProfile {
  final int id;
  final int userId;
  final String employeeCode;
  final String designation;
  final String assignedTerritory;
  final double? currentLat;
  final double? currentLng;
  final int batteryLevel;
  final String attendanceStatus;
  final String fullName;
  final String phone;
  final String? email;
  final bool isActive;

  FeProfile({
    required this.id,
    required this.userId,
    required this.employeeCode,
    required this.designation,
    required this.assignedTerritory,
    this.currentLat,
    this.currentLng,
    required this.batteryLevel,
    required this.attendanceStatus,
    required this.fullName,
    required this.phone,
    this.email,
    required this.isActive,
  });

  factory FeProfile.fromJson(Map<String, dynamic> json) {
    return FeProfile(
      id: json['id'],
      userId: json['user_id'],
      employeeCode: json['employee_code'] ?? '',
      designation: json['designation'] ?? '',
      assignedTerritory: json['assigned_territory'] ?? '',
      currentLat: (json['current_lat'] as num?)?.toDouble(),
      currentLng: (json['current_lng'] as num?)?.toDouble(),
      batteryLevel: json['battery_level'] ?? 0,
      attendanceStatus: json['attendance_status'] ?? 'Unknown',
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      isActive: json['is_active'] ?? false,
    );
  }
}
