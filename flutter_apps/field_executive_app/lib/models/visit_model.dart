class VisitModel {
  final int id;
  final int executiveId;
  final String executiveName;
  final String employeeCode;
  final int shopId;
  final String shopName;
  final String shopLocation;
  final String purpose;
  final String status;
  final DateTime? visitedAt;
  final String? photoUrl;
  final double? photoLat;
  final double? photoLng;
  final String? notes;
  final int bagsOrdered;
  final DateTime scheduledDate;

  VisitModel({
    required this.id,
    required this.executiveId,
    required this.executiveName,
    required this.employeeCode,
    required this.shopId,
    required this.shopName,
    required this.shopLocation,
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
    return VisitModel(
      id: json['id'],
      executiveId: json['executive_id'],
      executiveName: json['executive_name'] ?? '',
      employeeCode: json['employee_code'] ?? '',
      shopId: json['shop_id'],
      shopName: json['shop_name'] ?? '',
      shopLocation: json['shop_location'] ?? '',
      purpose: json['purpose'] ?? '',
      status: json['status'] ?? 'Pending',
      visitedAt: json['visited_at'] != null ? DateTime.tryParse(json['visited_at']) : null,
      photoUrl: json['photo_url'],
      photoLat: json['photo_lat'] != null ? (json['photo_lat'] as num).toDouble() : null,
      photoLng: json['photo_lng'] != null ? (json['photo_lng'] as num).toDouble() : null,
      notes: json['notes'],
      bagsOrdered: json['bags_ordered'] ?? 0,
      scheduledDate: DateTime.tryParse(json['scheduled_date'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isToday {
    final now = DateTime.now();
    return scheduledDate.year == now.year &&
        scheduledDate.month == now.month &&
        scheduledDate.day == now.day;
  }
}
