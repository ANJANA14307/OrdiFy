import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import 'product_variant.dart';

class VariantsListScreen extends StatefulWidget {
  final String productId;
  final String productName;

  const VariantsListScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<VariantsListScreen> createState() => _VariantsListScreenState();
}

class _VariantsListScreenState extends State<VariantsListScreen> {
  List<ProductVariant> _variants = [];
  bool _isLoading = true;
  String? _loadError;

  String get _variantsPath => '/products/${widget.productId}/variants';

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  Future<void> _loadVariants() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final response = await apiClient.get(_variantsPath);
      final responseData = Map<String, dynamic>.from(response.data as Map);
      final rawVariants = responseData['variants'];
      final variants = rawVariants is List
          ? rawVariants
                .whereType<Map>()
                .map(
                  (variant) => ProductVariant.fromJson(
                    Map<String, dynamic>.from(variant),
                  ),
                )
                .toList()
          : <ProductVariant>[];

      if (!mounted) return;
      setState(() {
        _variants = variants;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = _errorMessage(error);
        _isLoading = false;
      });
    }
  }

  Future<ProductVariant> _saveVariant(
    ProductVariant? existing,
    Map<String, dynamic> payload,
  ) async {
    final response = existing == null
        ? await apiClient.post(_variantsPath, data: payload)
        : await apiClient.patch(
            '$_variantsPath/${existing.id}',
            data: payload,
          );
    final responseData = Map<String, dynamic>.from(response.data as Map);
    return ProductVariant.fromJson(
      Map<String, dynamic>.from(responseData['variant'] as Map),
    );
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
    }
    return error.toString();
  }

  Future<void> _openEditor({ProductVariant? variant}) async {
    final savedVariant = await showModalBottomSheet<ProductVariant>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VariantEditorSheet(
        productName: widget.productName,
        existing: variant,
        onSave: (payload) => _saveVariant(variant, payload),
      ),
    );

    if (!mounted || savedVariant == null) return;
    await _loadVariants();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          variant == null ? 'Variant added' : 'Variant updated',
        ),
      ),
    );
  }

  Future<void> _setActive(ProductVariant variant, bool isActive) async {
    try {
      await apiClient.patch(
        '$_variantsPath/${variant.id}',
        data: {'is_active': isActive},
      );
      if (!mounted) return;
      setState(() {
        _variants = _variants
            .map(
              (item) => item.id == variant.id
                  ? ProductVariant(
                      id: item.id,
                      productId: item.productId,
                      businessId: item.businessId,
                      code: item.code,
                      attributes: item.attributes,
                      price: item.price,
                      stock: item.stock,
                      isActive: isActive,
                    )
                  : item,
            )
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isActive ? 'Variant enabled' : 'Variant disabled')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error))),
      );
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Code copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A08),
      appBar: AppBar(
        backgroundColor: const Color(0xFF08120F),
        foregroundColor: Colors.white,
        title: Text(
          'Variants and Codes',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: _loadError == null && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              backgroundColor: const Color(0xFF35E58F),
              foregroundColor: const Color(0xFF06100B),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Variant'),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.productName,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF35E58F)),
      );
    }

    if (_loadError != null) {
      return Center(
        child: _StateCard(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load variants',
          message: _loadError!,
          actionLabel: 'Retry',
          onAction: _loadVariants,
        ),
      );
    }

    if (_variants.isEmpty) {
      return Center(
        child: _StateCard(
          icon: Icons.sell_outlined,
          title: 'No variants yet',
          message: 'Add a variant to create a unique code for each option.',
          actionLabel: 'Add Variant',
          onAction: () => _openEditor(),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF35E58F),
      onRefresh: _loadVariants,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _variants.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final variant = _variants[index];
          return _VariantCard(
            variant: variant,
            onTap: () => _openEditor(variant: variant),
            onCopy: () => _copyCode(variant.code),
            onActiveChanged: (value) => _setActive(variant, value),
          );
        },
      ),
    );
  }
}

class _VariantCard extends StatelessWidget {
  final ProductVariant variant;
  final VoidCallback onTap;
  final VoidCallback onCopy;
  final ValueChanged<bool> onActiveChanged;

  const _VariantCard({
    required this.variant,
    required this.onTap,
    required this.onCopy,
    required this.onActiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    final attributes = variant.attributes.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('  ·  ');

    return Material(
      color: const Color(0xFF101A16),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      variant.code,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF35E58F),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy code',
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                  ),
                  Switch(
                    value: variant.isActive,
                    onChanged: onActiveChanged,
                    activeThumbColor: const Color(0xFF35E58F),
                  ),
                ],
              ),
              if (attributes.isNotEmpty) ...[
                Text(
                  attributes,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                '₹${variant.price.toStringAsFixed(2)}  ·  Stock ${variant.stock}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF101A16),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: const Color(0xFF35E58F)),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF35E58F),
              foregroundColor: const Color(0xFF06100B),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _VariantEditorSheet extends StatefulWidget {
  final String productName;
  final ProductVariant? existing;
  final Future<ProductVariant> Function(Map<String, dynamic> payload) onSave;

  const _VariantEditorSheet({
    required this.productName,
    required this.existing,
    required this.onSave,
  });

  @override
  State<_VariantEditorSheet> createState() => _VariantEditorSheetState();
}

class _VariantEditorSheetState extends State<_VariantEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sizeController;
  late final TextEditingController _colorController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _codeController;
  final Map<String, dynamic> _customAttributes = {};

  bool _codeWasEdited = false;
  bool _isSaving = false;
  String? _codeError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _sizeController = TextEditingController(
      text: existing?.attributes['size']?.toString() ?? '',
    );
    _colorController = TextEditingController(
      text: existing?.attributes['color']?.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: existing?.price.toString() ?? '',
    );
    _stockController = TextEditingController(
      text: existing?.stock.toString() ?? '',
    );
    _customAttributes.addAll(existing?.attributes ?? const {});
    _customAttributes.remove('size');
    _customAttributes.remove('color');
    _codeWasEdited = existing != null;
    _codeController = TextEditingController(
      text: existing?.code ?? _suggestedCode(),
    );
  }

  @override
  void dispose() {
    _sizeController.dispose();
    _colorController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String _segment(String value) {
    final normalized = value.trim().toLowerCase();
    const knownValues = {
      'black': 'BLK',
      'white': 'WHT',
      'red': 'RED',
      'blue': 'BLU',
      'green': 'GRN',
      'yellow': 'YLW',
      'navy': 'NVY',
      'gray': 'GRY',
      'grey': 'GRY',
      'pink': 'PNK',
      'brown': 'BRN',
      'beige': 'BEI',
      'small': 'S',
      'medium': 'M',
      'large': 'L',
      'extra small': 'XS',
      'extra large': 'XL',
      'xx large': 'XXL',
    };
    if (knownValues.containsKey(normalized)) return knownValues[normalized]!;

    final words = normalized
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.length > 1) {
      return words.map((word) => word[0]).join().toUpperCase();
    }
    return words.isEmpty ? '' : words.first.substring(0, words.first.length.clamp(1, 3)).toUpperCase();
  }

  String _suggestedCode() {
    final productName = widget.productName.toLowerCase();
    final prefix = productName.contains('t-shirt') || productName.contains('t shirt')
        ? 'TS'
        : _segment(widget.productName);
    final attributes = <String>[
      if (_colorController.text.trim().isNotEmpty)
        _segment(_colorController.text),
      if (_sizeController.text.trim().isNotEmpty)
        _segment(_sizeController.text),
      ..._customAttributes.values
          .map((value) => _segment(value.toString()))
          .where((value) => value.isNotEmpty),
    ];
    return [prefix, ...attributes].where((part) => part.isNotEmpty).join('-');
  }

  void _updateSuggestion() {
    if (_codeWasEdited) return;
    final suggestion = _suggestedCode();
    _codeController.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    setState(() => _codeError = null);
  }

  Map<String, dynamic> _attributes() {
    return {
      if (_sizeController.text.trim().isNotEmpty)
        'size': _sizeController.text.trim(),
      if (_colorController.text.trim().isNotEmpty)
        'color': _colorController.text.trim(),
      ..._customAttributes,
    };
  }

  String? _validateCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) return 'Code is required';
    if (!RegExp(r'^[A-Z0-9]+(?:-[A-Z0-9]+)*$').hasMatch(code)) {
      return 'Use uppercase letters, numbers, and hyphens only';
    }
    return null;
  }

  Future<void> _addCustomAttribute() async {
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    final result = await showDialog<MapEntry<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101A16),
        title: const Text(
          'Add attribute',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(labelText: 'Value'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final key = keyController.text.trim();
              final value = valueController.text.trim();
              if (key.isNotEmpty && value.isNotEmpty) {
                Navigator.pop(dialogContext, MapEntry(key, value));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    keyController.dispose();
    valueController.dispose();
    if (!mounted || result == null) return;
    setState(() {
      _customAttributes[result.key] = result.value;
      _saveError = null;
    });
    _updateSuggestion();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final codeError = _validateCode(_codeController.text);
    if (codeError != null) {
      setState(() => _codeError = codeError);
      return;
    }

    setState(() {
      _isSaving = true;
      _codeError = null;
      _saveError = null;
    });

    try {
      final saved = await widget.onSave({
        'code': _codeController.text.trim(),
        'attributes': _attributes(),
        'price': double.parse(_priceController.text.trim()),
        'stock': int.parse(_stockController.text.trim()),
        'is_active': widget.existing?.isActive ?? true,
      });
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      final message = _errorMessage(error);
      if (!mounted) return;
      setState(() {
        if (error is DioException && error.response?.statusCode == 409) {
          _codeError = message;
        } else {
          _saveError = message;
        }
        _isSaving = false;
      });
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF101A16),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existing == null ? 'Add Variant' : 'Edit Variant',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _editorField(
                        controller: _sizeController,
                        label: 'Size',
                        hint: 'M',
                        onChanged: (_) => _updateSuggestion(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _editorField(
                        controller: _colorController,
                        label: 'Color',
                        hint: 'Black',
                        onChanged: (_) => _updateSuggestion(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ..._customAttributes.entries.map(
                      (entry) => InputChip(
                        label: Text('${entry.key}: ${entry.value}'),
                        onDeleted: () {
                          setState(() => _customAttributes.remove(entry.key));
                          _updateSuggestion();
                        },
                      ),
                    ),
                    ActionChip(
                      label: const Text('Add attribute'),
                      avatar: const Icon(Icons.add_rounded, size: 18),
                      onPressed: _addCustomAttribute,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _editorField(
                  controller: _codeController,
                  label: 'SKU / Product code',
                  hint: 'TS-BLK-M',
                  errorText: _codeError,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9-]')),
                    _UpperCaseTextFormatter(),
                  ],
                  onChanged: (_) {
                    _codeWasEdited = true;
                    setState(() {
                      _codeError = _validateCode(_codeController.text);
                      _saveError = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _editorField(
                        controller: _priceController,
                        label: 'Price',
                        hint: '499',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final price = double.tryParse(value ?? '');
                          return price == null || price <= 0
                              ? 'Enter a valid price'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _editorField(
                        controller: _stockController,
                        label: 'Stock',
                        hint: '10',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final stock = int.tryParse(value ?? '');
                          return stock == null || stock < 0
                              ? 'Enter valid stock'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _saveError!,
                    style: const TextStyle(color: Color(0xFFFF7C7C)),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF35E58F),
                      foregroundColor: const Color(0xFF06100B),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.existing == null
                                ? 'Add Variant'
                                : 'Save Changes',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _editorField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? errorText,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    return newValue.copyWith(
      text: upper,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
