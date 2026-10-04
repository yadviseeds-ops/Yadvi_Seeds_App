class OrderItem {
  final int productId;
  final String productName;
  final String sku;
  final String imageUrl;
  final String packageSize;
  final int quantityBags;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.imageUrl,
    required this.packageSize,
    required this.quantityBags,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['product_id'],
      productName: json['product_name'] ?? '',
      sku: json['sku'] ?? '',
      imageUrl: json['image_url'] ?? '',
      packageSize: json['package_size'] ?? '',
      quantityBags: json['quantity_bags'] ?? 0,
    );
  }
}

class Order {
  final int id;
  final String orderNumber;
  final String shopName;
  final String shopLocation;
  final String deliveryAddress;
  final int totalQuantityBags;
  final String status;
  final String? assignedExecutiveName;
  final String? lrNumber;
  final String? transporterName;
  final String createdAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.orderNumber,
    required this.shopName,
    required this.shopLocation,
    required this.deliveryAddress,
    required this.totalQuantityBags,
    required this.status,
    this.assignedExecutiveName,
    this.lrNumber,
    this.transporterName,
    required this.createdAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      orderNumber: json['order_number'] ?? '',
      shopName: json['shop_name'] ?? '',
      shopLocation: json['shop_location'] ?? '',
      deliveryAddress: json['delivery_address'] ?? '',
      totalQuantityBags: json['total_quantity_bags'] ?? 0,
      status: json['status'] ?? 'New',
      assignedExecutiveName: json['assigned_executive_name'],
      lrNumber: json['lr_number'],
      transporterName: json['transporter_name'],
      createdAt: json['created_at'] ?? '',
      items: (json['items'] as List?)
              ?.map((i) => OrderItem.fromJson(i))
              .toList() ??
          [],
    );
  }
}
