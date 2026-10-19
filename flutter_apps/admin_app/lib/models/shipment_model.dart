class ShipmentModel {
  final int id;
  final int orderId;
  final String orderNumber;
  final String lrNumber;
  final String transporterName;
  final String? vehicleNumber;
  final String? driverName;
  final String? driverPhone;
  final DateTime dispatchDate;
  final String estimatedDelivery;
  final String status;
  final String currentLocation;
  final String shopName;
  final String shopLocation;
  final int totalBags;

  ShipmentModel({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.lrNumber,
    required this.transporterName,
    this.vehicleNumber,
    this.driverName,
    this.driverPhone,
    required this.dispatchDate,
    required this.estimatedDelivery,
    required this.status,
    required this.currentLocation,
    required this.shopName,
    required this.shopLocation,
    required this.totalBags,
  });

  factory ShipmentModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return ShipmentModel(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      orderNumber: json['order_number']?.toString() ?? '',
      lrNumber: json['lr_number']?.toString() ?? '',
      transporterName: json['transporter_name']?.toString() ?? '',
      vehicleNumber: json['vehicle_number']?.toString(),
      driverName: json['driver_name']?.toString(),
      driverPhone: json['driver_phone']?.toString(),
      dispatchDate: parseDate(json['dispatch_date']),
      estimatedDelivery: json['estimated_delivery']?.toString() ?? '',
      status: json['status']?.toString() ?? 'In Transit',
      currentLocation: json['current_location']?.toString() ?? '',
      shopName: json['shop_name']?.toString() ?? '',
      shopLocation: json['shop_location']?.toString() ?? '',
      totalBags: json['total_bags'] ?? 0,
    );
  }
}
