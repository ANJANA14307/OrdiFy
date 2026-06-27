import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _thresholdController = TextEditingController(text: '5');
  final _searchController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _showOnlyLowStock = false;

  String? _message;
  String? _editingProductId;
  String? _imageUrl;
  String _searchQuery = '';

  List<dynamic> _products = [];

  bool get _isEditing => _editingProductId != null;

  int get _lowStockCount {
    return _products.where((product) {
      final stock = _toInt(product['stock_count']);
      final threshold = _toInt(product['low_stock_threshold'], fallback: 5);
      return stock <= threshold;
    }).length;
  }

  int get _totalStockUnits {
    int total = 0;
    for (final product in _products) {
      total += _toInt(product['stock_count']);
    }
    return total;
  }

  int get _storeHealthScore {
    if (_products.isEmpty) return 0;

    final healthyProducts = _products.length - _lowStockCount;
    final score = ((healthyProducts / _products.length) * 100).round();

    return score.clamp(0, 100);
  }

  double get _inventoryValue {
    double total = 0;

    for (final product in _products) {
      final price = _toDouble(product['price']);
      final stock = _toInt(product['stock_count']);
      total += price * stock;
    }

    return total;
  }

  List<dynamic> get _filteredProducts {
    List<dynamic> items = List<dynamic>.from(_products);

    if (_showOnlyLowStock) {
      items = items.where((product) {
        final stock = _toInt(product['stock_count']);
        final threshold = _toInt(product['low_stock_threshold'], fallback: 5);
        return stock <= threshold;
      }).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      items = items.where((product) {
        final name = product['name']?.toString().toLowerCase() ?? '';
        return name.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return items;
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _formatIndianNumber(num value) {
    final rounded = value.round().toString();

    if (rounded.length <= 3) return rounded;

    final lastThree = rounded.substring(rounded.length - 3);
    String rest = rounded.substring(0, rounded.length - 3);

    final groups = <String>[];

    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }

    if (rest.isNotEmpty) {
      groups.insert(0, rest);
    }

    return '${groups.join(',')},$lastThree';
  }

  String _currency(dynamic value) {
    final amount = _toDouble(value);
    return '₹${_formatIndianNumber(amount)}';
  }

  String _inventoryInsight() {
    if (_products.isEmpty) {
      return 'Add your first product to start tracking your OrdiFy inventory.';
    }

    if (_lowStockCount > 0) {
      return '$_lowStockCount product needs restock attention today.';
    }

    return 'Your catalog is healthy. All products are above low-stock level.';
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _thresholdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts({bool clearMessage = true}) async {
    setState(() {
      _isLoading = true;
      if (clearMessage) {
        _message = null;
      }
    });

    try {
      final response = await apiClient.get('/products?page=1&limit=50');

      if (!mounted) return;

      setState(() {
        _products = response.data['products'] ?? [];
      });
    } catch (e) {
      debugPrint('PRODUCT LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _message = 'Could not load products';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage(
    ImageSource source, {
    VoidCallback? refreshSheet,
  }) async {
    try {
      final pickedImage = await _picker.pickImage(
        source: source,
        imageQuality: 75,
      );

      if (pickedImage == null) return;

      setState(() {
        _isUploadingImage = true;
        _message = null;
      });
      refreshSheet?.call();

      final response = await apiClient.uploadProductImage(pickedImage.path);

      if (!mounted) return;

      setState(() {
        _imageUrl = response.data['image_url'];
        _message = 'Image uploaded successfully';
      });
      refreshSheet?.call();
    } catch (e) {
      debugPrint('IMAGE UPLOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _message = 'Image upload failed';
      });
      refreshSheet?.call();
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
        refreshSheet?.call();
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _priceController.clear();
    _stockController.clear();
    _descriptionController.clear();
    _thresholdController.text = '5';

    setState(() {
      _editingProductId = null;
      _imageUrl = null;
    });
  }

  void _fillForm(dynamic product) {
    setState(() {
      _editingProductId = product['id']?.toString();

      _nameController.text = product['name']?.toString() ?? '';
      _priceController.text = product['price']?.toString() ?? '';
      _stockController.text = product['stock_count']?.toString() ?? '';
      _descriptionController.text = product['description']?.toString() ?? '';
      _thresholdController.text =
          product['low_stock_threshold']?.toString() ?? '5';
      _imageUrl = product['image_url']?.toString();

      _message = 'Editing ${product['name']}';
    });
  }

  Future<void> _saveProduct({
    VoidCallback? closeSheet,
    VoidCallback? refreshSheet,
  }) async {
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();
    final stockText = _stockController.text.trim();
    final description = _descriptionController.text.trim();
    final thresholdText = _thresholdController.text.trim();

    if (name.isEmpty) {
      setState(() => _message = 'Product name is required');
      refreshSheet?.call();
      return;
    }

    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      setState(() => _message = 'Enter a valid price');
      refreshSheet?.call();
      return;
    }

    final stock = int.tryParse(stockText);
    if (stock == null || stock < 0) {
      setState(() => _message = 'Enter a valid stock count');
      refreshSheet?.call();
      return;
    }

    final threshold = int.tryParse(thresholdText);
    if (threshold == null || threshold < 0) {
      setState(() => _message = 'Enter a valid low stock threshold');
      refreshSheet?.call();
      return;
    }

    setState(() {
      _isSaving = true;
      _message = null;
    });
    refreshSheet?.call();

    final data = {
      'name': name,
      'description': description.isEmpty ? null : description,
      'price': price,
      'stock_count': stock,
      'low_stock_threshold': threshold,
      'image_url': _imageUrl,
    };

    try {
      if (_isEditing) {
        await apiClient.patch(
          '/products/$_editingProductId',
          data: data,
        );

        if (!mounted) return;

        _clearForm();

        setState(() {
          _message = 'Product updated successfully';
        });
      } else {
        await apiClient.post(
          '/products',
          data: data,
        );

        if (!mounted) return;

        _clearForm();

        setState(() {
          _message = 'Product created successfully';
        });
      }

      await _loadProducts(clearMessage: false);
      closeSheet?.call();
    } catch (e) {
      debugPrint('PRODUCT SAVE ERROR: $e');

      if (!mounted) return;

      setState(() {
        _message =
            _isEditing ? 'Product update failed' : 'Product creation failed';
      });
      refreshSheet?.call();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        refreshSheet?.call();
      }
    }
  }

  Future<void> _deleteProduct(String productId) async {
    setState(() {
      _message = null;
    });

    try {
      await apiClient.delete('/products/$productId');

      if (!mounted) return;

      setState(() {
        _message = 'Product deleted successfully';
      });

      await _loadProducts(clearMessage: false);
    } catch (e) {
      debugPrint('PRODUCT DELETE ERROR: $e');

      if (!mounted) return;

      setState(() {
        _message = 'Product delete failed';
      });
    }
  }

  Future<void> _confirmDelete(dynamic product) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101A16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          title: Text(
            'Delete product?',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Remove "${product['name']}" from your OrdiFy inventory?',
            style: GoogleFonts.inter(
              color: Colors.white70,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Colors.white60,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFF6B7A),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteProduct(product['id'].toString());
    }
  }

  void _openProductSheet({dynamic product}) {
    if (product == null) {
      _clearForm();
    } else {
      _fillForm(product);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _ProductSheet(
              isEditing: _isEditing,
              isSaving: _isSaving,
              isUploadingImage: _isUploadingImage,
              imageUrl: _imageUrl,
              message: _message,
              nameController: _nameController,
              priceController: _priceController,
              stockController: _stockController,
              thresholdController: _thresholdController,
              descriptionController: _descriptionController,
              onGallery: () => _pickAndUploadImage(
                ImageSource.gallery,
                refreshSheet: () => setSheetState(() {}),
              ),
              onCamera: () => _pickAndUploadImage(
                ImageSource.camera,
                refreshSheet: () => setSheetState(() {}),
              ),
              onCancel: () {
                Navigator.pop(sheetContext);
                _clearForm();
              },
              onSave: () => _saveProduct(
                refreshSheet: () => setSheetState(() {}),
                closeSheet: () {
                  if (Navigator.canPop(sheetContext)) {
                    Navigator.pop(sheetContext);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Color _stockColor(int stock, int threshold) {
    if (stock <= threshold) return const Color(0xFFFFC857);
    return const Color(0xFF45F2A6);
  }

  bool _isLowStock(int stock, int threshold) {
    return stock <= threshold;
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFF050A08),
      body: Stack(
        children: [
          const _GreenBackground(),
          SafeArea(
            child: RefreshIndicator(
              color: const Color(0xFF35E58F),
              onRefresh: _loadProducts,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 145),
                children: [
                  _TopGreeting(
                    storeHealthScore: _storeHealthScore,
                    onAdd: () => _openProductSheet(),
                  ),
                  const SizedBox(height: 18),
                 _OverviewCard(
                productCount: _products.length,
                lowStockCount: _lowStockCount,
                totalUnits: _totalStockUnits,
                insight: _inventoryInsight(),
),
                  
                  const SizedBox(height: 14),
                  _InventoryValueCard(
                    totalValue: _currency(_inventoryValue),
                  ),
                  const SizedBox(height: 22),
                  _QuickActions(
                    showOnlyLowStock: _showOnlyLowStock,
                    onAdd: () => _openProductSheet(),
                    onRefresh: () => _loadProducts(),
                    onLowStock: () {
                      setState(() {
                        _showOnlyLowStock = !_showOnlyLowStock;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  _GreenSearchBar(controller: _searchController),
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    _MessageCard(message: _message!),
                  ],
                  const SizedBox(height: 22),
                  _CatalogHeader(
                    title: _showOnlyLowStock
                        ? 'Low Stock Products'
                        : 'Your Catalog',
                    count: products.length,
                    onRefresh: () => _loadProducts(),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF35E58F),
                        ),
                      ),
                    )
                  else if (products.isEmpty)
                    _EmptyCatalog(
                      showOnlyLowStock: _showOnlyLowStock,
                      onAdd: () => _openProductSheet(),
                      onClearFilter: () {
                        setState(() {
                          _showOnlyLowStock = false;
                          _searchController.clear();
                        });
                      },
                    )
                  else
                    ...products.map((product) {
                      final stock = _toInt(product['stock_count']);
                      final threshold = _toInt(
                        product['low_stock_threshold'],
                        fallback: 5,
                      );
                      final isLowStock = _isLowStock(stock, threshold);

                      return _ProductCard(
                        product: product,
                        stock: stock,
                        isLowStock: isLowStock,
                        stockColor: _stockColor(stock, threshold),
                        currency: _currency,
                        onEdit: () => _openProductSheet(product: product),
                        onDelete: () => _confirmDelete(product),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GreenBackground extends StatelessWidget {
  const _GreenBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF050A08),
                Color(0xFF08120F),
                Color(0xFF071B13),
              ],
            ),
          ),
        ),
        Positioned(
          top: -130,
          right: -90,
          child: _BlurCircle(
            size: 310,
            color: const Color(0xFF00B86B).withValues(alpha: 0.30),
          ),
        ),
        Positioned(
          bottom: -90,
          left: -110,
          child: _BlurCircle(
            size: 320,
            color: const Color(0xFF35E58F).withValues(alpha: 0.22),
          ),
        ),
        Positioned(
          top: 245,
          left: -130,
          child: _BlurCircle(
            size: 260,
            color: const Color(0xFF0E7A4F).withValues(alpha: 0.20),
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _BlurCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _BlurCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF15211D).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 26,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TopGreeting extends StatelessWidget {
  final int storeHealthScore;
  final VoidCallback onAdd;

  const _TopGreeting({
    required this.storeHealthScore,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF35E58F),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF06100B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good Evening!',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'OrdiFy Inventory',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(24),
          child: _GlassCard(
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                _HealthRing(score: storeHealthScore),
                const SizedBox(width: 8),
                Text(
                  'Store\nHealth',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HealthRing extends StatelessWidget {
  final int score;

  const _HealthRing({
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      width: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            color: const Color(0xFF35E58F),
          ),
          Text(
            '$score',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final int productCount;
  final int lowStockCount;
  final int totalUnits;
  final String insight;

  const _OverviewCard({
    required this.productCount,
    required this.lowStockCount,
    required this.totalUnits,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 30,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inventory Overview',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            insight,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                icon: Icons.inventory_2_rounded,
                label: '$productCount Products',
                color: const Color(0xFF35E58F),
              ),
              _StatusPill(
                icon: Icons.warning_amber_rounded,
                label: '$lowStockCount Low Stock',
                color: const Color(0xFFFFC857),
              ),
              _StatusPill(
                icon: Icons.layers_rounded,
                label: '$totalUnits Units',
                color: const Color(0xFF7BE0FF),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryValueCard extends StatelessWidget {
  final String totalValue;

  const _InventoryValueCard({
    required this.totalValue,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF35E58F).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: Color(0xFF35E58F),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  totalValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF35E58F),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total Inventory Value',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Based on product price × stock count',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final bool showOnlyLowStock;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;
  final VoidCallback onLowStock;

  const _QuickActions({
    required this.showOnlyLowStock,
    required this.onAdd,
    required this.onRefresh,
    required this.onLowStock,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.add_rounded,
                label: 'Add Product',
                onTap: onAdd,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.warning_amber_rounded,
                label: showOnlyLowStock ? 'Show All' : 'Low Stock',
                onTap: onLowStock,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.refresh_rounded,
                label: 'Refresh',
                onTap: onRefresh,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 86,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF15211D).withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF35E58F).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF35E58F),
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GreenSearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _GreenSearchBar({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 24,
      padding: EdgeInsets.zero,
      child: TextField(
        controller: controller,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Search products...',
          hintStyle: GoogleFonts.inter(
            color: Colors.white38,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF35E58F),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;

  const _MessageCard({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = message.contains('successfully');
    final color = isSuccess ? const Color(0xFF35E58F) : const Color(0xFFFFC857);

    return _GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Text(
        message,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onRefresh;

  const _CatalogHeader({
    required this.title,
    required this.count,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: GoogleFonts.inter(
            color: const Color(0xFF35E58F),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(
            Icons.refresh_rounded,
            color: Color(0xFF35E58F),
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final dynamic product;
  final int stock;
  final bool isLowStock;
  final Color stockColor;
  final String Function(dynamic value) currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.stock,
    required this.isLowStock,
    required this.stockColor,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = product['name']?.toString() ?? 'Unnamed Product';
    final description = product['description']?.toString() ?? '';
    final price = currency(product['price']);
    final imageUrl = product['image_url']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      child: _GlassCard(
        radius: 26,
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              height: 82,
              width: 82,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF35E58F).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(22),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return const _ProductFallbackIcon();
                      },
                    )
                  : const _ProductFallbackIcon(),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description.isEmpty ? price : '$price • $description',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: stockColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          isLowStock ? 'Low Stock' : 'Healthy',
                          style: GoogleFonts.inter(
                            color: stockColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Stock $stock',
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              color: const Color(0xFF101A16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text(
                    'Edit',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFF6B7A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductFallbackIcon extends StatelessWidget {
  const _ProductFallbackIcon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.inventory_2_rounded,
        color: Color(0xFF35E58F),
        size: 30,
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  final bool showOnlyLowStock;
  final VoidCallback onAdd;
  final VoidCallback onClearFilter;

  const _EmptyCatalog({
    required this.showOnlyLowStock,
    required this.onAdd,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 28,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_rounded,
            color: Color(0xFF35E58F),
            size: 42,
          ),
          const SizedBox(height: 14),
          Text(
            showOnlyLowStock ? 'No low stock products' : 'No products yet',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            showOnlyLowStock
                ? 'Your inventory looks healthy right now.'
                : 'Add your first product to start managing your seller catalog.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white54,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: showOnlyLowStock ? onClearFilter : onAdd,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF35E58F),
              foregroundColor: const Color(0xFF06100B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              showOnlyLowStock ? 'Show All Products' : 'Add Product',
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

class _ProductSheet extends StatelessWidget {
  final bool isEditing;
  final bool isSaving;
  final bool isUploadingImage;
  final String? imageUrl;
  final String? message;

  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController stockController;
  final TextEditingController thresholdController;
  final TextEditingController descriptionController;

  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _ProductSheet({
    required this.isEditing,
    required this.isSaving,
    required this.isUploadingImage,
    required this.imageUrl,
    required this.message,
    required this.nameController,
    required this.priceController,
    required this.stockController,
    required this.thresholdController,
    required this.descriptionController,
    required this.onGallery,
    required this.onCamera,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF101A16).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isEditing ? 'Edit Product' : 'New Product',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onCancel,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SheetImageBox(
                    imageUrl: imageUrl,
                    isUploading: isUploadingImage,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SheetButton(
                          icon: Icons.photo_library_rounded,
                          label: 'Gallery',
                          onTap: isUploadingImage ? null : onGallery,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SheetButton(
                          icon: Icons.camera_alt_rounded,
                          label: 'Camera',
                          onTap: isUploadingImage ? null : onCamera,
                        ),
                      ),
                    ],
                  ),
                  if (message != null &&
                      !message!.contains('successfully') &&
                      !message!.contains('Editing')) ...[
                    const SizedBox(height: 12),
                    Text(
                      message!,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFFC857),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _GreenInputField(
                    controller: nameController,
                    label: 'Product Name',
                    hint: 'Example: Handmade Bracelet',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _GreenInputField(
                          controller: priceController,
                          label: 'Price',
                          hint: '299',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _GreenInputField(
                          controller: stockController,
                          label: 'Stock',
                          hint: '10',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _GreenInputField(
                    controller: thresholdController,
                    label: 'Low Stock Threshold',
                    hint: '5',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _GreenInputField(
                    controller: descriptionController,
                    label: 'Description',
                    hint: 'Optional product details',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isSaving || isUploadingImage ? null : onSave,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF35E58F),
                        foregroundColor: const Color(0xFF06100B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Color(0xFF06100B),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isEditing ? 'Save Changes' : 'Create Product',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetImageBox extends StatelessWidget {
  final String? imageUrl;
  final bool isUploading;

  const _SheetImageBox({
    required this.imageUrl,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: isUploading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF35E58F),
              ),
            )
          : imageUrl != null && imageUrl!.isNotEmpty
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return const _SheetImageFallback();
                  },
                )
              : const _SheetImageFallback(),
    );
  }
}

class _SheetImageFallback extends StatelessWidget {
  const _SheetImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.cloud_upload_rounded,
        color: Color(0xFF35E58F),
        size: 48,
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SheetButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF35E58F),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.12),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class _GreenInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;

  const _GreenInputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: Colors.white30,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: Color(0xFF35E58F),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}