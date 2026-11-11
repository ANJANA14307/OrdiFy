class ProductVariant {
  final String id;
  final String productId;
  final String businessId;
  final String code;
  final Map<String, dynamic> attributes;
  final double price;
  final int stock;
  final bool isActive;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.businessId,
    required this.code,
    required this.attributes,
    required this.price,
    required this.stock,
    required this.isActive,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'];
    final price = json['price'];
    final stock = json['stock'];

    return ProductVariant(
      id: json['id'].toString(),
      productId: json['product_id'].toString(),
      businessId: json['business_id'].toString(),
      code: json['code'].toString(),
      attributes: attributes is Map
          ? Map<String, dynamic>.from(attributes)
          : const {},
      price: price is num ? price.toDouble() : double.parse(price.toString()),
      stock: stock is num ? stock.toInt() : int.parse(stock.toString()),
      isActive: json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'attributes': attributes,
    'price': price,
    'stock': stock,
    'is_active': isActive,
  };
}
