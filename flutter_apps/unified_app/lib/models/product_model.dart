class ProductModel {
  final int id;
  final String name;
  final String varietyType;
  final String sku;
  final String category;
  final String imageUrl;
  final double availableStockKg;
  final int availableStockBags;
  final String germinationRate;
  final String purity;
  final String? maturityDays;
  final String? cropSeason;
  final String availability;
  final String? description;
  final String? resistanceTraits;
  final String packageSizes;
  final bool isActive;

  ProductModel({
    required this.id,
    required this.name,
    required this.varietyType,
    required this.sku,
    required this.category,
    required this.imageUrl,
    required this.availableStockKg,
    this.availableStockBags = 0,
    required this.germinationRate,
    required this.purity,
    this.maturityDays,
    this.cropSeason,
    required this.availability,
    this.description,
    this.resistanceTraits,
    required this.packageSizes,
    required this.isActive,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final stockKg = (json['available_stock_kg'] != null)
        ? (json['available_stock_kg'] as num).toDouble()
        : ((json['available_stock_bags'] as num?)?.toDouble() ?? 0.0);
    final stockBags = (json['available_stock_bags'] != null)
        ? (json['available_stock_bags'] as num).toInt()
        : stockKg.toInt();

    return ProductModel(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      varietyType: json['variety_type']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      imageUrl: json['image_url']?.toString() ?? '',
      availableStockKg: stockKg,
      availableStockBags: stockBags,
      germinationRate: json['germination_rate']?.toString() ?? '85%',
      purity: json['purity']?.toString() ?? '98%',
      maturityDays: json['maturity_days']?.toString(),
      cropSeason: json['crop_season']?.toString(),
      availability: json['availability']?.toString() ?? 'In Stock',
      description: json['description']?.toString(),
      resistanceTraits: json['resistance_traits']?.toString(),
      packageSizes: json['package_sizes']?.toString() ?? '1kg',
      isActive: json['is_active'] ?? true,
    );
  }
}
