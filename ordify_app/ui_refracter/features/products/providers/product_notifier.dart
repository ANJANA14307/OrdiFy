import '../../../core/network/api_client.dart';
import '../models/product_model.dart';

class ProductsRepository {
  Future<List<ProductModel>> fetchProducts({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await apiClient.get('/products?page=$page&limit=$limit');

    final List productsJson = response.data['products'] ?? [];

    return productsJson
        .map((item) => ProductModel.fromJson(item))
        .toList();
  }

  Future<ProductModel> createProduct({
    required String name,
    String? description,
    required double price,
    required int stockCount,
    required int lowStockThreshold,
    String? imageUrl,
  }) async {
    final response = await apiClient.post(
      '/products',
      data: {
        'name': name,
        'description': description,
        'price': price,
        'stock_count': stockCount,
        'low_stock_threshold': lowStockThreshold,
        'image_url': imageUrl,
      },
    );

    return ProductModel.fromJson(response.data['product']);
  }

  Future<ProductModel> updateProduct({
    required String productId,
    required String name,
    String? description,
    required double price,
    required int stockCount,
    required int lowStockThreshold,
    String? imageUrl,
  }) async {
    final response = await apiClient.patch(
      '/products/$productId',
      data: {
        'name': name,
        'description': description,
        'price': price,
        'stock_count': stockCount,
        'low_stock_threshold': lowStockThreshold,
        'image_url': imageUrl,
      },
    );

    return ProductModel.fromJson(response.data['product']);
  }

  Future<void> deleteProduct(String productId) async {
    await apiClient.delete('/products/$productId');
  }

  Future<String> uploadProductImage(String filePath) async {
    final response = await apiClient.uploadProductImage(filePath);

    return response.data['image_url'];
  }
}

final productsRepository = ProductsRepository();