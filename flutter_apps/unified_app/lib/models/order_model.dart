class OrderItemModel {
  final int id;
  final int productId;
  final String productName;
  final String sku;
  final String imageUrl;
  final String packageSize;
  final double quantity;
  final String unit;
  final int quantityBags;

  OrderItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.imageUrl,
    required this.packageSize,
    required this.quantity,
    this.unit = 'kg',
    this.quantityBags = 0,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] != null)
        ? (json['quantity'] as num).toDouble()
        : ((json['quantity_bags'] as num?)?.toDouble() ?? 0.0);
    final unitStr = json['unit']?.toString() ?? 'kg';
    final bags = (json['quantity_bags'] != null)
        ? (json['quantity_bags'] as num).toInt()
        : qty.toInt();

    return OrderItemModel(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product_name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      packageSize: json['package_size']?.toString() ?? '',
      quantity: qty,
      unit: unitStr,
      quantityBags: bags,
    );
  }
}

class OrderModel {
  final int id;
  final String orderNumber;
  final int shopId;
  final String shopName;
  final String shopLocation;
  final String ownerName;
  final String contactPhone;
  final String deliveryAddress;
  final double totalQuantityKg;
  final int totalQuantityBags;
  final int totalItemsCount;
  final String status;
  final String source;
  final String? deliveryNotes;
  final String? assignedExecutiveName;
  final String? lrNumber;
  final String? transporterName;
  final DateTime? createdAt;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.shopId,
    required this.shopName,
    required this.shopLocation,
    required this.ownerName,
    required this.contactPhone,
    required this.deliveryAddress,
    required this.totalQuantityKg,
    this.totalQuantityBags = 0,
    required this.totalItemsCount,
    required this.status,
    required this.source,
    this.deliveryNotes,
    this.assignedExecutiveName,
    this.lrNumber,
    this.transporterName,
    this.createdAt,
    this.items = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    var itemsList = <OrderItemModel>[];
    if (json['items'] is List) {
      itemsList = (json['items'] as List)
          .map((item) => OrderItemModel.fromJson(item))
          .toList();
    }

    DateTime? created;
    if (json['created_at'] != null) {
      try {
        created = DateTime.parse(json['created_at'].toString());
      } catch (_) {}
    }

    final totalKg = (json['total_quantity_kg'] != null)
        ? (json['total_quantity_kg'] as num).toDouble()
        : ((json['total_quantity_bags'] as num?)?.toDouble() ?? 0.0);
    final bags = (json['total_quantity_bags'] != null)
        ? (json['total_quantity_bags'] as num).toInt()
        : totalKg.toInt();

    return OrderModel(
      id: json['id'] ?? 0,
      orderNumber: json['order_number']?.toString() ?? 'ORD-${json['id']}',
      shopId: json['shop_id'] ?? 0,
      shopName: json['shop_name']?.toString() ?? 'Shop #${json['shop_id']}',
      shopLocation: json['shop_location']?.toString() ?? '',
      ownerName: json['owner_name']?.toString() ?? '',
      contactPhone: json['contact_phone']?.toString() ?? '',
      deliveryAddress: json['delivery_address']?.toString() ?? '',
      totalQuantityKg: totalKg,
      totalQuantityBags: bags,
      totalItemsCount: json['total_items_count'] ?? itemsList.length,
      status: json['status']?.toString() ?? 'New',
      source: json['source']?.toString() ?? 'App',
      deliveryNotes: json['delivery_notes']?.toString(),
      assignedExecutiveName: json['assigned_executive_name']?.toString(),
      lrNumber: json['lr_number']?.toString(),
      transporterName: json['transporter_name']?.toString(),
      createdAt: created,
      items: itemsList,
    );
  }
}
