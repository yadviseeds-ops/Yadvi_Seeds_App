class EODReportModel {
  final int id;
  final int executiveId;
  final String executiveName;
  final DateTime reportDate;
  final int completedVisits;
  final int pendingVisits;
  final int totalBagsOrdered;
  final String? notes;
  final DateTime createdAt;

  EODReportModel({
    required this.id,
    required this.executiveId,
    required this.executiveName,
    required this.reportDate,
    required this.completedVisits,
    required this.pendingVisits,
    required this.totalBagsOrdered,
    this.notes,
    required this.createdAt,
  });

  factory EODReportModel.fromJson(Map<String, dynamic> json) {
    DateTime parseUtc(dynamic v) {
      if (v == null) return DateTime.now();
      String dateStr = v.toString().trim();
      if (dateStr.isEmpty) return DateTime.now();
      if (!dateStr.endsWith('Z')) {
        int tIndex = dateStr.indexOf('T');
        if (tIndex == -1) tIndex = dateStr.indexOf(' ');

        if (tIndex != -1) {
          String timePart = dateStr.substring(tIndex + 1);
          if (!timePart.contains('+') && !timePart.contains('-')) {
            dateStr += 'Z';
          }
        }
      }
      return DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now();
    }

    return EODReportModel(
      id: json['id'] ?? 0,
      executiveId: json['executive_id'] ?? 0,
      executiveName: json['executive_name']?.toString() ?? '',
      reportDate: parseUtc(json['report_date']),
      completedVisits: json['completed_visits'] ?? 0,
      pendingVisits: json['pending_visits'] ?? 0,
      totalBagsOrdered: json['total_bags_ordered'] ?? 0,
      notes: json['notes']?.toString(),
      createdAt: parseUtc(json['created_at']),
    );
  }
}
