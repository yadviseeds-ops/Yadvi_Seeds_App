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
  final String? username;
  final double debtTaken;
  final double debtRepaid;
  final double totalBalance;

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
    this.username,
    this.debtTaken = 0.0,
    this.debtRepaid = 0.0,
    this.totalBalance = 0.0,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    final taken = (json['debt_taken'] as num?)?.toDouble() ?? 0.0;
    final repaid = (json['debt_repaid'] as num?)?.toDouble() ?? 0.0;
    final balance = (json['total_balance'] as num?)?.toDouble() ??
        double.parse((taken - repaid).toStringAsFixed(2));

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
      username: json['username']?.toString(),
      debtTaken: taken,
      debtRepaid: repaid,
      totalBalance: balance,
    );
  }

  ShopModel copyWith({
    int? id,
    int? userId,
    String? shopName,
    String? dealerCode,
    String? marketLocation,
    String? territory,
    String? city,
    String? address,
    double? lat,
    double? lng,
    String? shopPhotoUrl,
    String? ownerPhotoUrl,
    int? openingStockBags,
    int? currentStockBags,
    String? primaryDemandCrop,
    String? status,
    String? ownerName,
    String? phone,
    String? email,
    int? assignedExecutiveId,
    String? assignedExecutiveName,
    String? username,
    double? debtTaken,
    double? debtRepaid,
    double? totalBalance,
  }) {
    final taken = debtTaken ?? this.debtTaken;
    final repaid = debtRepaid ?? this.debtRepaid;
    final balance = totalBalance ??
        double.parse((taken - repaid).toStringAsFixed(2));

    return ShopModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      shopName: shopName ?? this.shopName,
      dealerCode: dealerCode ?? this.dealerCode,
      marketLocation: marketLocation ?? this.marketLocation,
      territory: territory ?? this.territory,
      city: city ?? this.city,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      shopPhotoUrl: shopPhotoUrl ?? this.shopPhotoUrl,
      ownerPhotoUrl: ownerPhotoUrl ?? this.ownerPhotoUrl,
      openingStockBags: openingStockBags ?? this.openingStockBags,
      currentStockBags: currentStockBags ?? this.currentStockBags,
      primaryDemandCrop: primaryDemandCrop ?? this.primaryDemandCrop,
      status: status ?? this.status,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      assignedExecutiveId: assignedExecutiveId ?? this.assignedExecutiveId,
      assignedExecutiveName:
          assignedExecutiveName ?? this.assignedExecutiveName,
      username: username ?? this.username,
      debtTaken: taken,
      debtRepaid: repaid,
      totalBalance: balance,
    );
  }

  /// Formats currency amounts in Indian Rupees (₹) with proper comma separators.
  /// Handles positive, zero, and negative values cleanly.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'shop_name': shopName,
      'dealer_code': dealerCode,
      'market_location': marketLocation,
      'territory': territory,
      'city': city,
      'address': address,
      'lat': lat,
      'lng': lng,
      'shop_photo_url': shopPhotoUrl,
      'owner_photo_url': ownerPhotoUrl,
      'opening_stock_bags': openingStockBags,
      'current_stock_bags': currentStockBags,
      'primary_demand_crop': primaryDemandCrop,
      'status': status,
      'owner_name': ownerName,
      'phone': phone,
      'email': email,
      'assigned_executive_id': assignedExecutiveId,
      'assigned_executive_name': assignedExecutiveName,
      'username': username,
      'debt_taken': debtTaken,
      'debt_repaid': debtRepaid,
      'total_balance': totalBalance,
    };
  }

  static String formatCurrency(double amount) {
    if (amount == 0.0) {
      return '₹0.00';
    }
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final parts = absAmount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    String res = '';
    if (intPart.length > 3) {
      final last3 = intPart.substring(intPart.length - 3);
      final remaining = intPart.substring(0, intPart.length - 3);
      final reg = RegExp(r'\B(?=(\d{2})+(?!\d))');
      res = '${remaining.replaceAll(reg, ',')},$last3';
    } else {
      res = intPart;
    }

    final formatted = decPart == '00' ? res : '$res.$decPart';
    return isNegative ? '-₹$formatted' : '₹$formatted';
  }
}
