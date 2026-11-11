import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import 'catalog_models.dart';
import 'catalog_preview_screen.dart';
import 'product_share_preview.dart';

class CatalogShareScreen extends StatefulWidget {
  const CatalogShareScreen({super.key});

  @override
  State<CatalogShareScreen> createState() => _CatalogShareScreenState();
}

class _CatalogShareScreenState extends State<CatalogShareScreen> {
  CatalogSettings? _catalog;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _listings = [];
  Set<String> _selectedIds = {};
  Set<String> _selectedListingIds = {};
  String _businessName = 'My Business';
  String _search = '';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await apiClient.get('/catalogs/me');
      final data = Map<String, dynamic>.from(response.data as Map);
      final catalog = CatalogSettings.fromJson(
        Map<String, dynamic>.from(data['catalog'] as Map),
      );
      final rawProducts = data['products'];
      final rawListings = data['listings'];
      final products = rawProducts is List
          ? rawProducts
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];
      final listings = rawListings is List
          ? rawListings.whereType<Map>().map((rawListing) {
              final listing = Map<String, dynamic>.from(rawListing);
              final product = listing['catalog_product'] is Map
                  ? Map<String, dynamic>.from(listing['catalog_product'] as Map)
                  : <String, dynamic>{};
              final variants = listing['variants'] is List
                  ? (listing['variants'] as List)
                        .whereType<Map>()
                        .map((variant) => Map<String, dynamic>.from(variant))
                        .toList()
                  : <Map<String, dynamic>>[];
              return <String, dynamic>{
                'id': listing['id']?.toString(),
                'listing_id': listing['id']?.toString(),
                'catalog_product_id': listing['catalog_product_id'],
                'name': product['name'] ?? 'Product',
                'brand': product['brand'],
                'category': product['category'],
                'description': product['description'],
                'price': listing['price'],
                'stock_count': listing['stock'],
                'image_url': (product['images'] as List?)?.firstOrNull,
                'variants': variants,
                'code': variants.isEmpty ? null : variants.first['code'],
              };
            }).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _products = products;
        _listings = listings;
        final activeIds = products
            .map((product) => product['id']?.toString())
            .whereType<String>()
            .toSet();
        _selectedIds = catalog.selectedProductIds
            .where(activeIds.contains)
            .toSet();
        final activeListingIds = listings
            .map((listing) => listing['listing_id']?.toString())
            .whereType<String>()
            .toSet();
        _selectedListingIds = catalog.selectedListingIds
            .where(activeListingIds.contains)
            .toSet();
        _businessName = data['business'] is Map
            ? (data['business']['name']?.toString() ?? 'My Business')
            : 'My Business';
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _errorMessageFor(error);
        _isLoading = false;
      });
    }
  }

  String _errorMessageFor(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'You appear to be offline. Check your connection and retry.';
      }
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
    }
    return error.toString();
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final query = _search.trim().toLowerCase();
    final entries = [..._products, ..._listings];
    if (query.isEmpty) return entries;
    return entries.where((product) {
      final name = product['name']?.toString().toLowerCase() ?? '';
      final code = product['code']?.toString().toLowerCase() ?? '';
      return name.contains(query) || code.contains(query);
    }).toList();
  }

  Future<void> _saveCatalog() async {
    if (_selectedIds.isEmpty &&
        _selectedListingIds.isEmpty &&
        _catalog?.isPublic == true) {
      _showMessage('Select at least one product before publishing');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final response = await apiClient.put(
        '/catalogs/me',
        data: {
          'is_public': _catalog?.isPublic ?? false,
          'selected_product_ids': _selectedIds.toList(),
          'selected_listing_ids': _selectedListingIds.toList(),
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final catalog = CatalogSettings.fromJson(
        Map<String, dynamic>.from(data['catalog'] as Map),
      );
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _selectedIds = catalog.selectedProductIds.toSet();
        _selectedListingIds = catalog.selectedListingIds.toSet();
        _isSaving = false;
      });
      _showMessage('Catalog settings saved');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _errorMessageFor(error);
        _isSaving = false;
      });
    }
  }

  Future<void> _setPublic(bool isPublic) async {
    final previous = _catalog!;
    if (isPublic && _selectedIds.isEmpty && _selectedListingIds.isEmpty) {
      _showMessage('Select at least one product before publishing');
      return;
    }
    setState(() {
      _catalog = CatalogSettings(
        slug: previous.slug,
        isPublic: isPublic,
        selectedProductIds: previous.selectedProductIds,
        selectedListingIds: previous.selectedListingIds,
        url: previous.url,
      );
    });
    await _saveCatalog();
    if (!mounted || _errorMessage == null) return;
    setState(() => _catalog = previous);
  }

  Future<void> _copyLink() async {
    final url = _catalog?.url;
    if (url == null || url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    _showMessage('Catalog link copied');
  }

  Future<void> _shareMore() async {
    final url = _catalog?.url;
    if (url == null) return;
    await SharePlus.instance.share(
      ShareParams(text: 'Browse $_businessName’s catalog: $url'),
    );
  }

  Future<void> _shareWhatsApp() async {
    final url = _catalog?.url;
    if (url == null) return;
    final text = 'Browse $_businessName’s catalog: $url';
    final uri = Uri.https('wa.me', '/', {'text': text});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await _shareMore();
    }
  }

  Future<void> _shareSms() async {
    final url = _catalog?.url;
    if (url == null) return;
    final uri = Uri(
      scheme: 'sms',
      queryParameters: {'body': 'Browse $_businessName’s catalog: $url'},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await _shareMore();
    }
  }

  void _openPreview() {
    final catalog = _catalog;
    if (catalog == null) return;
    final previewProducts = [
      ..._products.where(
        (product) => _selectedIds.contains(product['id']?.toString()),
      ),
      ..._listings.where(
        (listing) =>
            _selectedListingIds.contains(listing['listing_id']?.toString()),
      ),
    ];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogPreviewScreen(
          slug: catalog.slug,
          previewData: {
            'catalog': {
              'slug': catalog.slug,
              'is_public': catalog.isPublic,
              'url': catalog.url,
            },
            'business': {'name': _businessName},
            'products': previewProducts,
          },
        ),
      ),
    );
  }

  void _instagramHelp() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101A16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share on Instagram',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Add to your bio:\n1. Copy your catalog link.\n2. Open Instagram and edit your profile.\n3. Paste it in the Links section and save.\n\nShare in a story:\n1. Create a story.\n2. Add a Link sticker.\n3. Paste your catalog link and publish.',
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _copyLink();
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy Catalog Link'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openProductShare(Map<String, dynamic> product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductSharePreview(
          product: product,
          businessName: _businessName,
          isCatalogPublic: _catalog?.isPublic == true,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1711),
        foregroundColor: Colors.white,
        title: Text(
          'Share Catalog',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF34F087)),
              )
            : _errorMessage != null && _catalog == null
            ? _errorState()
            : _products.isEmpty && _listings.isEmpty
            ? _emptyState()
            : _content(),
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
            const Icon(Icons.cloud_off, color: Color(0xFFFF7D88), size: 42),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: _loadCatalog, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF34F087),
              size: 44,
            ),
            SizedBox(height: 12),
            Text(
              'No products to share',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add an active product to build your catalog.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final catalog = _catalog!;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _linkCard(catalog),
        const SizedBox(height: 14),
        _qrCard(catalog.url),
        const SizedBox(height: 14),
        _sharingCard(),
        const SizedBox(height: 14),
        _visibilityCard(catalog),
        const SizedBox(height: 14),
        _productsCard(),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Color(0xFFFF7D88)),
          ),
        ],
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101A16),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  Widget _linkCard(CatalogSettings catalog) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your catalog link',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            catalog.url,
            style: const TextStyle(color: Color(0xFF34F087)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openPreview,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Preview'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qrCard(String url) {
    return _card(
      child: Row(
        children: [
          QrImageView(
            data: url,
            size: 112,
            backgroundColor: Colors.white,
            padding: const EdgeInsets.all(8),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Customers can scan this QR code to open your catalog.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sharingCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share your catalog',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _shareButton(
                'WhatsApp',
                Icons.chat_rounded,
                const Color(0xFF34F087),
                _shareWhatsApp,
              ),
              _shareButton(
                'Instagram',
                Icons.camera_alt_rounded,
                const Color(0xFFFF8FAB),
                _instagramHelp,
              ),
              _shareButton(
                'SMS',
                Icons.sms_outlined,
                const Color(0xFF9DDCFB),
                _shareSms,
              ),
              _shareButton(
                'More',
                Icons.ios_share_rounded,
                Colors.white70,
                _shareMore,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shareButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 17, color: color),
      label: Text(label),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
    );
  }

  Widget _visibilityCard(CatalogSettings catalog) {
    return _card(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: catalog.isPublic,
        onChanged: _isSaving ? null : _setPublic,
        activeThumbColor: const Color(0xFF34F087),
        title: const Text(
          'Catalog is public',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          catalog.isPublic
              ? 'Anyone with the link can see selected products.'
              : 'Your catalog link is private until you publish.',
          style: const TextStyle(color: Colors.white60),
        ),
      ),
    );
  }

  Widget _productsCard() {
    final filteredProducts = _filteredProducts;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Products and listings in catalog',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (value) => setState(() => _search = value),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search products',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...filteredProducts.map(_productTile),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _saveCatalog,
              child: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Catalog Selection'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productTile(Map<String, dynamic> product) {
    final productId = product['id']?.toString() ?? '';
    final listingId = product['listing_id']?.toString();
    final selected = listingId == null
        ? _selectedIds.contains(productId)
        : _selectedListingIds.contains(listingId);
    final code = product['code']?.toString();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: selected,
        activeColor: const Color(0xFF34F087),
        onChanged: (value) {
          setState(() {
            if (value == true) {
              if (listingId == null) {
                _selectedIds.add(productId);
              } else {
                _selectedListingIds.add(listingId);
              }
            } else {
              if (listingId == null) {
                _selectedIds.remove(productId);
              } else {
                _selectedListingIds.remove(listingId);
              }
            }
          });
        },
      ),
      title: Text(
        product['name']?.toString() ?? 'Product',
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        '₹${product['price'] ?? 0}${code == null ? '' : ' · Code $code'}',
        style: const TextStyle(color: Colors.white60),
      ),
      trailing: IconButton(
        tooltip: 'Share product',
        onPressed: () => _openProductShare(product),
        icon: const Icon(Icons.share_outlined, color: Color(0xFF34F087)),
      ),
    );
  }
}
