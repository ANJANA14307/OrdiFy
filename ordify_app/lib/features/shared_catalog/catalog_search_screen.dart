import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import 'shared_catalog_api.dart';
import 'shared_catalog_models.dart';

class CatalogSearchScreen extends StatefulWidget {
  const CatalogSearchScreen({super.key});

  @override
  State<CatalogSearchScreen> createState() => _CatalogSearchScreenState();
}

class _CatalogSearchScreenState extends State<CatalogSearchScreen> {
  final _queryController = TextEditingController();
  final _brandController = TextEditingController();
  final _categoryController = TextEditingController();
  List<CatalogProduct> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await sharedCatalogApi.search(
        query: _queryController.text,
        brand: _brandController.text,
        category: _categoryController.text,
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = sharedCatalogError(error);
        _loading = false;
      });
    }
  }

  Future<void> _showDetails(CatalogProduct product) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101A14),
      builder: (_) => CatalogProductDetailSheet(product: product),
    );
    if (result == true && mounted) {
      context.push(
        '/shared-catalog/listing/${product.id}',
        extra: product.toJson(),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF050807),
    appBar: AppBar(
      title: const Text('Find in OrdiFy catalog'),
      backgroundColor: const Color(0xFF07120C),
      foregroundColor: Colors.white,
      actions: [
        IconButton(onPressed: _search, icon: const Icon(Icons.refresh_rounded)),
        IconButton(
          tooltip: 'My listings',
          onPressed: () => context.push('/shared-catalog/listings'),
          icon: const Icon(Icons.storefront_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _queryController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Search name',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: _search,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _brandController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    labelText: 'Brand',
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _categoryController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _loading ? null : _search,
            icon: const Icon(Icons.filter_alt_outlined),
            label: const Text('Search catalog'),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _SearchMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Search failed',
              message: _error!,
              actionLabel: 'Retry',
              onAction: _search,
            )
          else if (_products.isEmpty)
            _SearchMessage(
              icon: Icons.search_off_rounded,
              title: 'No matching products',
              message: 'Not found? Create new product.',
              actionLabel: 'Create new product',
              onAction: () => context.push('/shared-catalog/suggest'),
            )
          else
            ..._products.map(
              (product) => Card(
                color: const Color(0xFF101A14),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => _showDetails(product),
                  leading: _ProductImage(url: product.images.firstOrNull),
                  title: Text(product.name),
                  subtitle: Text(
                    [
                      if (product.brand?.isNotEmpty == true) product.brand!,
                      product.category,
                    ].join(' • '),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class CatalogProductDetailSheet extends StatelessWidget {
  const CatalogProductDetailSheet({required this.product, super.key});

  final CatalogProduct product;

  Future<void> _linkExistingProduct(BuildContext context) async {
    try {
      if (!context.mounted) return;
      final ownedResponse = await _loadOwnedProducts();
      if (!context.mounted) return;
      final selectedProductId = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF101A14),
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Choose one of your products',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              ...ownedResponse.map(
                (item) => ListTile(
                  title: Text(item['name']?.toString() ?? 'Product'),
                  onTap: () => Navigator.pop(context, item['id'].toString()),
                ),
              ),
            ],
          ),
        ),
      );
      if (selectedProductId == null || !context.mounted) return;
      await sharedCatalogApi.mapProduct(selectedProductId, product.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Catalog product linked to your product')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(sharedCatalogError(error))));
    }
  }

  Future<List<Map<String, dynamic>>> _loadOwnedProducts() async {
    final response = await apiClient.get('/products?page=1&limit=50');
    final products = response.data['products'];
    if (products is! List) return const [];
    return products
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: _ProductImage(url: product.images.firstOrNull, size: 96),
          ),
          const SizedBox(height: 14),
          Text(
            product.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          if (product.brand?.isNotEmpty == true)
            Text('Brand: ${product.brand}'),
          Text('Category: ${product.category}'),
          if (product.description?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              product.description!,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Sell this product'),
            ),
          ),
          TextButton.icon(
            onPressed: () => _linkExistingProduct(context),
            icon: const Icon(Icons.link_rounded),
            label: const Text('Link one of my existing products'),
          ),
        ],
      ),
    ),
  );
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.url, this.size = 54});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: size,
      height: size,
      color: Colors.white10,
      child: url == null || url!.isEmpty
          ? const Icon(Icons.inventory_2_outlined, color: Colors.white54)
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
              ),
            ),
    ),
  );
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
    child: Column(
      children: [
        Icon(icon, size: 42, color: const Color(0xFF34F087)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (actionLabel != null) ...[
          const SizedBox(height: 14),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}
