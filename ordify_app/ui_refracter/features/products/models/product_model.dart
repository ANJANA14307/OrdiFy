class ProductModel {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final double price;
  final int stockCount;
  final String? imageUrl;
  final bool isActive;
  final int lowStockThreshold;
  final DateTime? createdAt;

  ProductModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.price,
    required this.stockCount,
    required this.imageUrl,
    required this.isActive,
    required this.lowStockThreshold,
    required this.createdAt,
  });

  bool get isLowStock => stockCount <= lowStockThreshold;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Product',
      description: json['description']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      stockCount: (json['stock_count'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url']?.toString(),
      isActive: json['is_active'] == true,
      lowStockThreshold:
          (json['low_stock_threshold'] as num?)?.toInt() ?? 5,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}