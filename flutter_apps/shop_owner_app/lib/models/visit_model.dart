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
    this.notes,
    required this.bagsOrdered,
    required this.scheduledDate,
  });

  factory VisitModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseUtc(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      // Check if there is a timezone offset after the time part
      if (!dateStr.endsWith('Z')) {
        // Find the 'T' or space separating date and time
        int tIndex = dateStr.indexOf('T');
        if (tIndex == -1) tIndex = dateStr.indexOf(' ');
        
        if (tIndex != -1) {
          String timePart = dateStr.substring(tIndex + 1);
          if (!timePart.contains('+') && !timePart.contains('-')) {
            dateStr += 'Z';
          }
        }
      }
      return DateTime.tryParse(dateStr)?.toLocal();
    }

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
      visitedAt: parseUtc(json['visited_at']),
      photoUrl: json['photo_url'],
      notes: json['notes'],
      bagsOrdered: json['bags_ordered'] ?? 0,
      scheduledDate: parseUtc(json['scheduled_date']) ?? DateTime.now(),
    );
  }

  bool get isToday {
    final now = DateTime.now();
    return scheduledDate.year == now.year &&
        scheduledDate.month == now.month &&
        scheduledDate.day == now.day;
  }
}
