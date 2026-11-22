class AttendanceModel {
  final int id;
  final int executiveId;
  final String employeeCode;
  final String fullName;
  final String? phone;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String status;
  final double distanceCoveredKm;
  final String? checkInLocation;

  AttendanceModel({
    required this.id,
    required this.executiveId,
    required this.employeeCode,
    required this.fullName,
    this.phone,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    required this.distanceCoveredKm,
    this.checkInLocation,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    DateTime? parseNullableDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return AttendanceModel(
      id: json['id'] ?? 0,
      executiveId: json['executive_id'] ?? 0,
      employeeCode: json['employee_code']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Unknown',
      phone: json['phone']?.toString(),
      date: parseDate(json['date']),
      checkInTime: parseNullableDate(json['check_in_time']),
      checkOutTime: parseNullableDate(json['check_out_time']),
      status: json['status']?.toString() ?? 'Absent',
      distanceCoveredKm: (json['distance_covered_km'] as num?)?.toDouble() ?? 0.0,
      checkInLocation: json['check_in_location']?.toString(),
    );
  }
}
