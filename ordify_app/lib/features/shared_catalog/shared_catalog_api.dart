import 'package:dio/dio.dart';

import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import 'shared_catalog_models.dart';

class SharedCatalogApi {
  Future<List<CatalogProduct>> search({
    String? query,
    String? brand,
    String? category,
  }) async {
    final response = await apiClient.get(
      '/shared-catalog/products',
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (brand != null && brand.trim().isNotEmpty) 'brand': brand.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
      },
    );
    return (response.data['products'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CatalogProduct.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<CatalogProduct> getProduct(String id) async {
    final response = await apiClient.get('/shared-catalog/products/$id');
    return CatalogProduct.fromJson(
      Map<String, dynamic>.from(response.data['product'] as Map),
    );
  }

  Future<CatalogProduct> suggest(Map<String, dynamic> payload) async {
    final response = await apiClient.post(
      '/shared-catalog/suggestions',
      data: payload,
    );
    return CatalogProduct.fromJson(
      Map<String, dynamic>.from(response.data['product'] as Map),
    );
  }

  Future<BusinessListing> createListing(Map<String, dynamic> payload) async {
    final response = await apiClient.post(
      '/shared-catalog/listings',
      data: payload,
    );
    return BusinessListing.fromJson(
      Map<String, dynamic>.from(response.data['listing'] as Map),
    );
  }

  Future<List<BusinessListing>> myListings() async {
    final response = await apiClient.get(
      '/shared-catalog/listings',
      queryParameters: {'include_inactive': true},
    );
    return (response.data['listings'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => BusinessListing.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<BusinessListing> updateListing(
    String listingId,
    Map<String, dynamic> values,
  ) async {
    final response = await apiClient.patch(
      '/shared-catalog/listings/$listingId',
      data: values,
    );
    return BusinessListing.fromJson(
      Map<String, dynamic>.from(response.data['listing'] as Map),
    );
  }

  Future<Map<String, dynamic>?> getMapping(String productId) async {
    final response = await apiClient.get('/shared-catalog/mappings/$productId');
    final mapping = response.data['mapping'];
    return mapping is Map ? Map<String, dynamic>.from(mapping) : null;
  }

  Future<void> mapProduct(String productId, String catalogProductId) async {
    await apiClient.put(
      '/shared-catalog/mappings/$productId',
      data: {'catalog_product_id': catalogProductId},
    );
  }

  Future<void> unmapProduct(String productId) async {
    await apiClient.delete('/shared-catalog/mappings/$productId');
  }

  Future<String> uploadImage(XFile image) async {
    final response = await apiClient.uploadProductImage(image);
    final imageUrl = response.data['image_url']?.toString();
    if (imageUrl == null || imageUrl.isEmpty) {
      throw StateError('Image upload did not return an image URL');
    }
    return imageUrl;
  }
}

String sharedCatalogError(Object error) {
  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map && body['detail'] != null) {
      final detail = body['detail'];
      if (detail is List) {
        return detail
            .whereType<Map>()
            .map((item) => item['msg']?.toString())
            .whereType<String>()
            .join('\n');
      }
      return detail.toString();
    }
  }
  return error.toString();
}

final sharedCatalogApi = SharedCatalogApi();
