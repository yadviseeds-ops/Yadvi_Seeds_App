class OrderItem {
  final int productId;
  final String productName;
  final String sku;
  final String imageUrl;
  final String packageSize;
  final double quantity;
  final String unit;
  final int quantityBags;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.imageUrl,
    required this.packageSize,
    required this.quantity,
    this.unit = 'kg',
    this.quantityBags = 0,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] != null)
        ? (json['quantity'] as num).toDouble()
        : ((json['quantity_bags'] as num?)?.toDouble() ?? 0.0);
    final unitStr = json['unit']?.toString() ?? 'kg';
    final bags = (json['quantity_bags'] != null)
        ? (json['quantity_bags'] as num).toInt()
        : qty.toInt();

    return OrderItem(
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      sku: json['sku'] ?? '',
      imageUrl: json['image_url'] ?? '',
      packageSize: json['package_size'] ?? '',
      quantity: qty,
      unit: unitStr,
      quantityBags: bags,
    );
  }
}

class Order {
  final int id;
  final String orderNumber;
  final String shopName;
  final String shopLocation;
  final String deliveryAddress;
  final double totalQuantityKg;
  final int totalItemsCount;
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
    required this.totalQuantityKg,
    this.totalItemsCount = 0,
    this.totalQuantityBags = 0,
    required this.status,
    this.assignedExecutiveName,
    this.lrNumber,
    this.transporterName,
    required this.createdAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List?)
            ?.map((i) => OrderItem.fromJson(i))
            .toList() ??
        [];
    final totalKg = (json['total_quantity_kg'] != null)
        ? (json['total_quantity_kg'] as num).toDouble()
        : ((json['total_quantity_bags'] as num?)?.toDouble() ?? 0.0);
    final bags = (json['total_quantity_bags'] != null)
        ? (json['total_quantity_bags'] as num).toInt()
        : totalKg.toInt();

    return Order(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      shopName: json['shop_name'] ?? '',
      shopLocation: json['shop_location'] ?? '',
      deliveryAddress: json['delivery_address'] ?? '',
      totalQuantityKg: totalKg,
      totalItemsCount: json['total_items_count'] ?? itemsList.length,
      totalQuantityBags: bags,
      status: json['status'] ?? 'New',
      assignedExecutiveName: json['assigned_executive_name'],
      lrNumber: json['lr_number'],
      transporterName: json['transporter_name'],
      createdAt: json['created_at'] ?? '',
      items: itemsList,
    );
  }
}
