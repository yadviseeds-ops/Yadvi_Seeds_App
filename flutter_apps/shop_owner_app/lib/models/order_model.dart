class OrderModel {
  final int id;
  final String orderNumber;
  final String shopName;
  final String shopLocation;
  final String ownerName;
  final String contactPhone;
  final String deliveryAddress;
  final int totalQuantityBags;
  final String status;
  final String? assignedExecutiveName;
  final String? lrNumber;
  final String? transporterName;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.shopName,
    required this.shopLocation,
    required this.ownerName,
    required this.contactPhone,
    required this.deliveryAddress,
    required this.totalQuantityBags,
    required this.status,
    this.assignedExecutiveName,
    this.lrNumber,
    this.transporterName,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      orderNumber: json['order_number'] ?? '',
      shopName: json['shop_name'] ?? '',
      shopLocation: json['shop_location'] ?? '',
      ownerName: json['owner_name'] ?? '',
      contactPhone: json['contact_phone'] ?? '',
      deliveryAddress: json['delivery_address'] ?? '',
      totalQuantityBags: json['total_quantity_bags'] ?? 0,
      status: json['status'] ?? '',
      assignedExecutiveName: json['assigned_executive_name'],
      lrNumber: json['lr_number'],
      transporterName: json['transporter_name'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
