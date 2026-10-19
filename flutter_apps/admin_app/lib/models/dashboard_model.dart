class KPICardModel {
  final String label;
  final String value;
  final String sub;
  final String trend;

  KPICardModel({
    required this.label,
    required this.value,
    required this.sub,
    required this.trend,
  });

  factory KPICardModel.fromJson(Map<String, dynamic> json) {
    return KPICardModel(
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      sub: json['sub']?.toString() ?? '',
      trend: json['trend']?.toString() ?? 'neutral',
    );
  }
}

class DashboardDataModel {
  final List<KPICardModel> kpis;
  final int totalOrders;
  final int pendingOrders;
  final int dispatchedOrders;
  final int deliveredOrders;
  final int totalProducts;
  final int totalShops;
  final int totalExecutives;
  final int presentToday;
  final int totalVisitsToday;
  final int completedVisitsToday;

  DashboardDataModel({
    required this.kpis,
    required this.totalOrders,
    required this.pendingOrders,
    required this.dispatchedOrders,
    required this.deliveredOrders,
    required this.totalProducts,
    required this.totalShops,
    required this.totalExecutives,
    required this.presentToday,
    required this.totalVisitsToday,
    required this.completedVisitsToday,
  });

  factory DashboardDataModel.fromJson(Map<String, dynamic> json) {
    var kpisList = <KPICardModel>[];
    if (json['kpis'] is List) {
      kpisList = (json['kpis'] as List)
          .map((item) => KPICardModel.fromJson(item))
          .toList();
    }

    return DashboardDataModel(
      kpis: kpisList,
      totalOrders: json['total_orders'] ?? 0,
      pendingOrders: json['pending_orders'] ?? 0,
      dispatchedOrders: json['dispatched_orders'] ?? 0,
      deliveredOrders: json['delivered_orders'] ?? 0,
      totalProducts: json['total_products'] ?? 0,
      totalShops: json['total_shops'] ?? 0,
      totalExecutives: json['total_executives'] ?? 0,
      presentToday: json['present_today'] ?? 0,
      totalVisitsToday: json['total_visits_today'] ?? 0,
      completedVisitsToday: json['completed_visits_today'] ?? 0,
    );
  }
}
