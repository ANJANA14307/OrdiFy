class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.images,
    this.brand,
    this.description,
  });

  final String id;
  final String name;
  final String category;
  final List<String> images;
  final String? brand;
  final String? description;

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    return CatalogProduct(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      brand: json['brand']?.toString(),
      description: json['description']?.toString(),
      images: rawImages is List
          ? rawImages.map((value) => value.toString()).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'category': category,
    'description': description,
    'images': images,
  };
}

class BusinessListing {
  const BusinessListing({
    required this.id,
    required this.catalogProductId,
    required this.product,
    required this.price,
    required this.stock,
    required this.isActive,
    required this.variants,
    this.deliveryOverride,
    this.returnPolicyOverride,
  });

  final String id;
  final String catalogProductId;
  final CatalogProduct product;
  final double price;
  final int stock;
  final bool isActive;
  final List<Map<String, dynamic>> variants;
  final Map<String, dynamic>? deliveryOverride;
  final Map<String, dynamic>? returnPolicyOverride;

  factory BusinessListing.fromJson(Map<String, dynamic> json) =>
      BusinessListing(
        id: json['id']?.toString() ?? '',
        catalogProductId: json['catalog_product_id']?.toString() ?? '',
        product: CatalogProduct.fromJson(
          Map<String, dynamic>.from(json['catalog_product'] as Map),
        ),
        price: _number(json['price']),
        stock: _number(json['stock']).toInt(),
        isActive: json['is_active'] == true,
        variants: (json['variants'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
        deliveryOverride: json['delivery_override'] is Map
            ? Map<String, dynamic>.from(json['delivery_override'] as Map)
            : null,
        returnPolicyOverride: json['return_policy_override'] is Map
            ? Map<String, dynamic>.from(json['return_policy_override'] as Map)
            : null,
      );
}

class ProductCatalogMapping {
  const ProductCatalogMapping({
    required this.productId,
    required this.businessId,
    required this.catalogProductId,
  });

  final String productId;
  final String businessId;
  final String catalogProductId;

  factory ProductCatalogMapping.fromJson(Map<String, dynamic> json) =>
      ProductCatalogMapping(
        productId: json['product_id']?.toString() ?? '',
        businessId: json['business_id']?.toString() ?? '',
        catalogProductId: json['catalog_product_id']?.toString() ?? '',
      );
}

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
