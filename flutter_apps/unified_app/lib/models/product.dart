class Product {
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
  final String maturityDays;
  final String cropSeason;
  final String availability;
  final String description;
  final List<String> packageSizes;

  Product({
    required this.id,
    required this.name,
    required this.varietyType,
    required this.sku,
    required this.category,
    required this.imageUrl,
    required this.availableStockKg,
    this.availableStockBags = 0,
    this.germinationRate = '',
    this.purity = '',
    this.maturityDays = '',
    this.cropSeason = '',
    this.availability = 'In Stock',
    this.description = '',
    this.packageSizes = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final stockKg = (json['available_stock_kg'] != null)
        ? (json['available_stock_kg'] as num).toDouble()
        : ((json['available_stock_bags'] as num?)?.toDouble() ?? 0.0);
    final stockBags = (json['available_stock_bags'] != null)
        ? (json['available_stock_bags'] as num).toInt()
        : stockKg.toInt();

    return Product(
      id: json['id'],
      name: json['name'] ?? '',
      varietyType: json['variety_type'] ?? '',
      sku: json['sku'] ?? '',
      category: json['category'] ?? '',
      imageUrl: json['image_url'] ?? '',
      availableStockKg: stockKg,
      availableStockBags: stockBags,
      germinationRate: json['germination_rate'] ?? '',
      purity: json['purity'] ?? '',
      maturityDays: json['maturity_days'] ?? '',
      cropSeason: json['crop_season'] ?? '',
      availability: json['availability'] ?? '',
      description: json['description'] ?? '',
      packageSizes: (json['package_sizes'] as String?)
              ?.split(',')
              .map((e) => e.trim())
              .toList() ??
          [],
    );
  }
}
