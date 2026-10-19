class ShopModel {
  final int id;
  final int userId;
  final String shopName;
  final String dealerCode;
  final String marketLocation;
  final String? territory;
  final String? city;
  final String address;
  final double? lat;
  final double? lng;
  final String? shopPhotoUrl;
  final String? ownerPhotoUrl;
  final int openingStockBags;
  final int currentStockBags;
  final String? primaryDemandCrop;
  final String status;
  final String ownerName;
  final String phone;
  final String? email;
  final int? assignedExecutiveId;
  final String? assignedExecutiveName;

  ShopModel({
    required this.id,
    required this.userId,
    required this.shopName,
    this.dealerCode = '',
    required this.marketLocation,
    this.territory,
    this.city,
    required this.address,
    this.lat,
    this.lng,
    this.shopPhotoUrl,
    this.ownerPhotoUrl,
    required this.openingStockBags,
    required this.currentStockBags,
    this.primaryDemandCrop,
    required this.status,
    required this.ownerName,
    required this.phone,
    this.email,
    this.assignedExecutiveId,
    this.assignedExecutiveName,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      shopName: json['shop_name']?.toString() ?? '',
      dealerCode: json['dealer_code']?.toString() ?? '',
      marketLocation: json['market_location']?.toString() ?? '',
      territory: json['territory']?.toString(),
      city: json['city']?.toString(),
      address: json['address']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      shopPhotoUrl: json['shop_photo_url']?.toString(),
      ownerPhotoUrl: json['owner_photo_url']?.toString(),
      openingStockBags: json['opening_stock_bags'] ?? 0,
      currentStockBags: json['current_stock_bags'] ?? 0,
      primaryDemandCrop: json['primary_demand_crop']?.toString(),
      status: json['status']?.toString() ?? 'Active',
      ownerName: json['owner_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      assignedExecutiveId: json['assigned_executive_id'],
      assignedExecutiveName: json['assigned_executive_name']?.toString(),
    );
  }
}
