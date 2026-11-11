import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import 'product_share_preview.dart';

class CatalogPreviewScreen extends StatefulWidget {
  final String slug;
  final String? productId;
  final Map<String, dynamic>? previewData;

  const CatalogPreviewScreen({
    super.key,
    required this.slug,
    this.productId,
    this.previewData,
  });

  @override
  State<CatalogPreviewScreen> createState() => _CatalogPreviewScreenState();
}

class _CatalogPreviewScreenState extends State<CatalogPreviewScreen> {
  Map<String, dynamic>? _catalog;
  String _businessName = 'Store';
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _search = '';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    final data = widget.previewData;
    if (data != null) {
      _setCatalogData(data);
    } else {
      _loadPublicCatalog();
    }
  }

  void _setCatalogData(Map<String, dynamic> data) {
    final rawProducts = data['products'];
    _catalog = data['catalog'] is Map
        ? Map<String, dynamic>.from(data['catalog'] as Map)
        : null;
    _businessName = data['business'] is Map
        ? (data['business']['name']?.toString() ?? 'Store')
        : 'Store';
    _products = rawProducts is List
        ? rawProducts
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : [];
    _isLoading = false;
  }

  Future<void> _loadPublicCatalog() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await apiClient.get('/catalogs/public/${widget.slug}');
      _setCatalogData(Map<String, dynamic>.from(response.data as Map));
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  List<String> get _categories {
    final values =
        _products
            .map((product) => product['category']?.toString().trim() ?? '')
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...values];
  }

  List<Map<String, dynamic>> get _visibleProducts {
    final query = _search.trim().toLowerCase();
    final visible = _products.where((product) {
      final name = product['name']?.toString().toLowerCase() ?? '';
      final code = product['code']?.toString().toLowerCase() ?? '';
      final category = product['category']?.toString() ?? '';
      return (query.isEmpty || name.contains(query) || code.contains(query)) &&
          (_selectedCategory == 'All' || category == _selectedCategory);
    }).toList();
    if (widget.productId == null) return visible;
    return visible
        .where((product) => product['id']?.toString() == widget.productId)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isPrivate = _catalog?['is_public'] != true;
    return Scaffold(
      backgroundColor: const Color(0xFF080E0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1711),
        foregroundColor: Colors.white,
        title: Text(
          _businessName,
          style: GoogleFonts.inter(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF34F087)),
              )
            : _errorMessage != null
            ? _errorState()
            : _products.isEmpty
            ? const Center(
                child: Text(
                  'No products in this catalog yet.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _businessHeader(),
                          if (isPrivate) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFFC857,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    color: Color(0xFFFFC857),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Private catalog — only you can preview it.',
                                      style: TextStyle(
                                        color: Color(0xFFFFC857),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextField(
                            onChanged: (value) =>
                                setState(() => _search = value),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search products',
                              hintStyle: const TextStyle(color: Colors.white38),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.white54,
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _categories.map((category) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(category),
                                    selected: _selectedCategory == category,
                                    onSelected: (_) => setState(
                                      () => _selectedCategory = category,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_visibleProducts.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'No matching products',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.crossAxisExtent;
                          final columns = width > 800
                              ? 4
                              : width > 520
                              ? 3
                              : 2;
                          return SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _ProductTile(
                                product: _visibleProducts[index],
                                businessName: _businessName,
                              ),
                              childCount: _visibleProducts.length,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.68,
                                ),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _loadPublicCatalog,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _businessHeader() {
    final url = _catalog?['url']?.toString() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF103E2C), Color(0xFF101A16)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.storefront_rounded,
            size: 32,
            color: Color(0xFF34F087),
          ),
          const SizedBox(height: 10),
          Text(
            _businessName,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (url.isNotEmpty)
            Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final String businessName;

  const _ProductTile({required this.product, required this.businessName});

  @override
  Widget build(BuildContext context) {
    final stockValue = product['stock_count'];
    final inStock = stockValue is num
        ? stockValue > 0
        : int.tryParse('$stockValue') != null && int.parse('$stockValue') > 0;
    final image = product['image_url']?.toString();
    final variants = product['variants'];
    final codes = variants is List
        ? variants
              .whereType<Map>()
              .map((variant) => variant['code']?.toString() ?? '')
              .where((code) => code.isNotEmpty)
              .toList()
        : <String>[
            if (product['code']?.toString().isNotEmpty == true)
              product['code'].toString(),
          ];

    return Material(
      color: const Color(0xFF111A16),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProductSharePreview(
              product: product,
              businessName: businessName,
              isCatalogPublic: true,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: image == null || image.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFF1A2A22),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 42,
                          color: Color(0xFF34F087),
                        ),
                      )
                    : Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFF1A2A22),
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name']?.toString() ?? 'Product',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${product['price'] ?? 0}',
                    style: const TextStyle(
                      color: Color(0xFF34F087),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (codes.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: codes
                          .map(
                            (code) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                code,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ] else ...[
                    const SizedBox(height: 5),
                    const Text(
                      'Code not set',
                      style: TextStyle(
                        color: Color(0xFFFFC857),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    inStock ? 'In stock' : 'Out of stock',
                    style: TextStyle(
                      color: inStock
                          ? const Color(0xFF34F087)
                          : const Color(0xFFFF7D88),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
