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
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return EODReportModel(
      id: json['id'] ?? 0,
      executiveId: json['executive_id'] ?? 0,
      executiveName: json['executive_name']?.toString() ?? '',
      reportDate: parseDate(json['report_date']),
      completedVisits: json['completed_visits'] ?? 0,
      pendingVisits: json['pending_visits'] ?? 0,
      totalBagsOrdered: json['total_bags_ordered'] ?? 0,
      notes: json['notes']?.toString(),
      createdAt: parseDate(json['created_at']),
    );
  }
}
