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
    return ShipmentModel(
      id: json['id'],
      orderId: json['order_id'],
      orderNumber: json['order_number'] ?? '',
      lrNumber: json['lr_number'] ?? '',
      transporterName: json['transporter_name'] ?? '',
      vehicleNumber: json['vehicle_number'],
      driverName: json['driver_name'],
      driverPhone: json['driver_phone'],
      dispatchDate: DateTime.tryParse(json['dispatch_date'] ?? '') ?? DateTime.now(),
      estimatedDelivery: json['estimated_delivery'] ?? '',
      status: json['status'] ?? '',
      currentLocation: json['current_location'] ?? '',
      shopName: json['shop_name'] ?? '',
      shopLocation: json['shop_location'] ?? '',
      totalBags: json['total_bags'] ?? 0,
    );
  }
}
