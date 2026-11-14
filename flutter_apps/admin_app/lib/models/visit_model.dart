class VisitModel {
  final int id;
  final int executiveId;
  final String executiveName;
  final String employeeCode;
  final int shopId;
  final String shopName;
  final String shopLocation;
  final String? shopOwnerName;
  final String? shopPhone;
  final String purpose;
  final String status;
  final DateTime? visitedAt;
  final String? photoUrl;
  final double? photoLat;
  final double? photoLng;
  final String? notes;
  final int bagsOrdered;
  final DateTime scheduledDate;

  String? get feedback => notes;

  VisitModel({
    required this.id,
    required this.executiveId,
    required this.executiveName,
    required this.employeeCode,
    required this.shopId,
    required this.shopName,
    required this.shopLocation,
    this.shopOwnerName,
    this.shopPhone,
    required this.purpose,
    required this.status,
    this.visitedAt,
    this.photoUrl,
    this.photoLat,
    this.photoLng,
    this.notes,
    required this.bagsOrdered,
    required this.scheduledDate,
  });

  factory VisitModel.fromJson(Map<String, dynamic> json) {
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

    return VisitModel(
      id: json['id'] ?? 0,
      executiveId: json['executive_id'] ?? 0,
      executiveName: json['executive_name']?.toString() ?? '',
      employeeCode: json['employee_code']?.toString() ?? '',
      shopId: json['shop_id'] ?? 0,
      shopName: json['shop_name']?.toString() ?? '',
      shopLocation: json['shop_location']?.toString() ?? '',
      shopOwnerName: json['shop_owner_name']?.toString(),
      shopPhone: json['shop_phone']?.toString(),
      purpose: json['purpose']?.toString() ?? 'Routine Visit',
      status: json['status']?.toString() ?? 'Pending',
      visitedAt: parseNullableDate(json['visited_at']),
      photoUrl: json['photo_url']?.toString(),
      photoLat: (json['photo_lat'] as num?)?.toDouble(),
      photoLng: (json['photo_lng'] as num?)?.toDouble(),
      notes: json['notes']?.toString(),
      bagsOrdered: json['bags_ordered'] ?? 0,
      scheduledDate: parseDate(json['scheduled_date']),
    );
  }
}
