class Product {
  final int id;
  final String name;
  final String varietyType;
  final String sku;
  final String category;
  final String imageUrl;
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
    required this.availableStockBags,
    required this.germinationRate,
    required this.purity,
    required this.maturityDays,
    required this.cropSeason,
    required this.availability,
    required this.description,
    required this.packageSizes,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'] ?? '',
      varietyType: json['variety_type'] ?? '',
      sku: json['sku'] ?? '',
      category: json['category'] ?? '',
      imageUrl: json['image_url'] ?? '',
      availableStockBags: json['available_stock_bags'] ?? 0,
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
