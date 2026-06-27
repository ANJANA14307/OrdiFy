import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/products_repository.dart';
import '../models/product_model.dart';

enum ProductsStatus {
  initial,
  loading,
  loaded,
  error,
  submitting,
}

class ProductsState {
  final ProductsStatus status;
  final List<ProductModel> products;
  final String? errorMessage;
  final String? successMessage;

  const ProductsState({
    required this.status,
    required this.products,
    this.errorMessage,
    this.successMessage,
  });

  factory ProductsState.initial() {
    return const ProductsState(
      status: ProductsStatus.initial,
      products: [],
    );
  }

  ProductsState copyWith({
    ProductsStatus? status,
    List<ProductModel>? products,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ProductsState(
      status: status ?? this.status,
      products: products ?? this.products,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage:
          clearSuccess ? null : successMessage ?? this.successMessage,
    );
  }

  bool get isLoading => status == ProductsStatus.loading;
  bool get isSubmitting => status == ProductsStatus.submitting;
  bool get hasProducts => products.isNotEmpty;
}

class ProductsNotifier extends StateNotifier<ProductsState> {
  ProductsNotifier(this._repository) : super(ProductsState.initial());

  final ProductsRepository _repository;

  Future<void> loadProducts() async {
    state = state.copyWith(
      status: ProductsStatus.loading,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final products = await _repository.fetchProducts();

      state = state.copyWith(
        status: ProductsStatus.loaded,
        products: products,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: ProductsStatus.error,
        errorMessage: 'Could not load products',
      );
    }
  }

  Future<void> createProduct({
    required String name,
    String? description,
    required double price,
    required int stockCount,
    required int lowStockThreshold,
    String? imageUrl,
  }) async {
    state = state.copyWith(
      status: ProductsStatus.submitting,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _repository.createProduct(
        name: name,
        description: description,
        price: price,
        stockCount: stockCount,
        lowStockThreshold: lowStockThreshold,
        imageUrl: imageUrl,
      );

      final products = await _repository.fetchProducts();

      state = state.copyWith(
        status: ProductsStatus.loaded,
        products: products,
        successMessage: 'Product created successfully',
      );
    } catch (e) {
      state = state.copyWith(
        status: ProductsStatus.error,
        errorMessage: 'Product creation failed',
      );
    }
  }

  Future<void> updateProduct({
    required String productId,
    required String name,
    String? description,
    required double price,
    required int stockCount,
    required int lowStockThreshold,
    String? imageUrl,
  }) async {
    state = state.copyWith(
      status: ProductsStatus.submitting,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _repository.updateProduct(
        productId: productId,
        name: name,
        description: description,
        price: price,
        stockCount: stockCount,
        lowStockThreshold: lowStockThreshold,
        imageUrl: imageUrl,
      );

      final products = await _repository.fetchProducts();

      state = state.copyWith(
        status: ProductsStatus.loaded,
        products: products,
        successMessage: 'Product updated successfully',
      );
    } catch (e) {
      state = state.copyWith(
        status: ProductsStatus.error,
        errorMessage: 'Product update failed',
      );
    }
  }

  Future<void> deleteProduct(String productId) async {
    state = state.copyWith(
      status: ProductsStatus.submitting,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _repository.deleteProduct(productId);

      final products = await _repository.fetchProducts();

      state = state.copyWith(
        status: ProductsStatus.loaded,
        products: products,
        successMessage: 'Product deleted successfully',
      );
    } catch (e) {
      state = state.copyWith(
        status: ProductsStatus.error,
        errorMessage: 'Product delete failed',
      );
    }
  }

  Future<String?> uploadProductImage(String filePath) async {
    state = state.copyWith(
      status: ProductsStatus.submitting,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final imageUrl = await _repository.uploadProductImage(filePath);

      state = state.copyWith(
        status: ProductsStatus.loaded,
        successMessage: 'Image uploaded successfully',
      );

      return imageUrl;
    } catch (e) {
      state = state.copyWith(
        status: ProductsStatus.error,
        errorMessage: 'Image upload failed',
      );

      return null;
    }
  }

  void clearMessages() {
    state = state.copyWith(
      clearError: true,
      clearSuccess: true,
    );
  }
}

final productsNotifierProvider =
    StateNotifierProvider<ProductsNotifier, ProductsState>((ref) {
  return ProductsNotifier(productsRepository);
});