import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/products_notifier.dart';
import '../widgets/add_product_sheet.dart';
import '../widgets/product_card.dart';
import 'edit_product_screen.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(productsNotifierProvider.notifier).loadProducts();
    });
  }

  void _openAddProductSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101010),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (_) {
        return const AddProductSheet();
      },
    );
  }

  Future<void> _openEditScreen(product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProductScreen(product: product),
      ),
    );
  }

  Future<void> _deleteProduct(String productId) async {
    await ref.read(productsNotifierProvider.notifier).deleteProduct(productId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsNotifierProvider);
    final products = state.products;
    final lowStockCount = products.where((product) => product.isLowStock).length;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddProductSheet,
        backgroundColor: const Color(0xFF00FFCC),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add Product',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF00FFCC),
          onRefresh: () {
            return ref.read(productsNotifierProvider.notifier).loadProducts();
          },
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Inventory',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Manage your product catalog, stock, and images.',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Products',
                      value: products.length.toString(),
                      icon: Icons.inventory_2_rounded,
                      color: const Color(0xFF00FFCC),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Low Stock',
                      value: lowStockCount.toString(),
                      icon: Icons.warning_amber_rounded,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Product List',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      ref
                          .read(productsNotifierProvider.notifier)
                          .loadProducts();
                    },
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF00FFCC),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (state.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.30),
                    ),
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: GoogleFonts.inter(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],

              if (state.successMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FFCC).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00FFCC).withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    state.successMessage!,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF00FFCC),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],

              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00FFCC),
                    ),
                  ),
                )
              else if (products.isEmpty)
                _EmptyProductsCard(
                  onAddProduct: _openAddProductSheet,
                )
              else
                ...products.map(
                  (product) => ProductCard(
                    product: product,
                    onEdit: () => _openEditScreen(product),
                    onDelete: () => _deleteProduct(product.id),
                  ),
                ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: color.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 26,
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProductsCard extends StatelessWidget {
  final VoidCallback onAddProduct;

  const _EmptyProductsCard({
    required this.onAddProduct,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_rounded,
            color: Color(0xFF00FFCC),
            size: 42,
          ),
          const SizedBox(height: 14),
          Text(
            'No products yet',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first product and start managing your inventory.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: onAddProduct,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FFCC),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Add Product',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}