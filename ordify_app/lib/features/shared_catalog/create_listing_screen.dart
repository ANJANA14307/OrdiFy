import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'shared_catalog_api.dart';
import 'shared_catalog_models.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({
    required this.catalogProductId,
    this.initialProduct,
    super.key,
  });

  final String catalogProductId;
  final Map<String, dynamic>? initialProduct;

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _deliveryFeeController = TextEditingController();
  final _returnDaysController = TextEditingController();
  final _returnTextController = TextEditingController();
  CatalogProduct? _product;
  final List<Map<String, dynamic>> _variants = [];
  bool _loading = true;
  bool _saving = false;
  bool _deliveryOverrideEnabled = false;
  bool _returnOverrideEnabled = false;
  bool _duplicateListing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _stockController.dispose();
    _deliveryFeeController.dispose();
    _returnDaysController.dispose();
    _returnTextController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final initial = widget.initialProduct;
      final product = initial == null
          ? await sharedCatalogApi.getProduct(widget.catalogProductId)
          : CatalogProduct.fromJson(initial);
      if (!mounted) return;
      setState(() {
        _product = product;
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

  Future<void> _addVariant() async {
    final variant = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101A14),
      builder: (_) => const _ListingVariantEditor(),
    );
    if (variant == null || !mounted) return;
    final code = variant['code']?.toString() ?? '';
    if (_variants.any((item) => item['code'] == code)) {
      _message('This code is already used in this listing');
      return;
    }
    setState(() => _variants.add(variant));
  }

  Future<void> _save() async {
    final price = double.tryParse(_priceController.text.trim());
    final stock = int.tryParse(_stockController.text.trim());
    final deliveryFee = _deliveryOverrideEnabled
        ? double.tryParse(_deliveryFeeController.text.trim())
        : null;
    final returnDays = _returnOverrideEnabled
        ? int.tryParse(_returnDaysController.text.trim())
        : null;
    if (price == null || price <= 0) {
      _message('Enter a valid listing price');
      return;
    }
    if (stock == null || stock < 0) {
      _message('Enter a valid stock count');
      return;
    }
    if (_deliveryOverrideEnabled && (deliveryFee == null || deliveryFee < 0)) {
      _message('Enter a valid delivery override');
      return;
    }
    if (_returnOverrideEnabled &&
        (returnDays == null || returnDays < 1 || returnDays > 365)) {
      _message('Return window override must be between 1 and 365 days');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _duplicateListing = false;
    });
    try {
      await sharedCatalogApi.createListing({
        'catalog_product_id': widget.catalogProductId,
        'price': price,
        'stock': stock,
        'variants': _variants,
        'delivery_override': _deliveryOverrideEnabled
            ? {'fee': deliveryFee}
            : null,
        'return_policy_override': _returnOverrideEnabled
            ? {
                'return_window_days': returnDays,
                'policy_text': _returnTextController.text.trim(),
              }
            : null,
      });
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Your listing was created');
      context.go('/shared-catalog/listings');
    } catch (error) {
      if (!mounted) return;
      final message = sharedCatalogError(error);
      setState(() {
        _error = message;
        _duplicateListing =
            message.toLowerCase().contains('already have a listing') ||
            message.toLowerCase().contains('duplicate');
        _saving = false;
      });
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF050807),
    appBar: AppBar(
      title: const Text('Create your listing'),
      backgroundColor: const Color(0xFF07120C),
      foregroundColor: Colors.white,
      actions: [
        IconButton(onPressed: _loadProduct, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _product == null
        ? _ListingMessage(
            message: _error ?? 'Catalog product unavailable',
            onRetry: _loadProduct,
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Card(
                  color: _duplicateListing
                      ? const Color(0xFF3A2D12)
                      : Colors.red.withValues(alpha: .18),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          _duplicateListing
                              ? Icons.warning_amber_rounded
                              : Icons.error_outline,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!)),
                      ],
                    ),
                  ),
                ),
              _card(
                title: 'Shared catalog details (read-only)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: _CatalogProductImage(
                        url: _product!.images.firstOrNull,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _readOnly('Name', _product!.name),
                    _readOnly('Brand', _product!.brand ?? '—'),
                    _readOnly('Category', _product!.category),
                    _readOnly('Description', _product!.description ?? '—'),
                  ],
                ),
              ),
              _card(
                title: 'Your business listing',
                child: Column(
                  children: [
                    TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Your price',
                        prefixText: '₹ ',
                      ),
                    ),
                    TextField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Your stock',
                      ),
                    ),
                  ],
                ),
              ),
              _card(
                title: 'Your variants and codes',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_variants.isEmpty)
                      const Text(
                        'No variants yet. Add optional size/color variants and their business-specific codes.',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ..._variants.map(
                      (variant) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(variant['code'].toString()),
                        subtitle: Text(
                          '${variant['attributes']} • ₹${variant['price']} • stock ${variant['stock']}',
                        ),
                        trailing: IconButton(
                          onPressed: () =>
                              setState(() => _variants.remove(variant)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _addVariant,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add variant'),
                    ),
                  ],
                ),
              ),
              _card(
                title: 'Delivery override',
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Set a delivery fee for this listing'),
                      value: _deliveryOverrideEnabled,
                      onChanged: (value) =>
                          setState(() => _deliveryOverrideEnabled = value),
                    ),
                    if (_deliveryOverrideEnabled)
                      TextField(
                        controller: _deliveryFeeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Delivery fee override',
                          prefixText: '₹ ',
                        ),
                      ),
                  ],
                ),
              ),
              _card(
                title: 'Return policy override',
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Set a return policy for this listing'),
                      value: _returnOverrideEnabled,
                      onChanged: (value) =>
                          setState(() => _returnOverrideEnabled = value),
                    ),
                    if (_returnOverrideEnabled) ...[
                      TextField(
                        controller: _returnDaysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Return window (days)',
                        ),
                      ),
                      TextField(
                        controller: _returnTextController,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Policy text',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.storefront_outlined),
                label: Text(_saving ? 'Saving…' : 'Create my listing'),
              ),
            ],
          ),
  );

  Widget _card({required String title, required Widget child}) => Card(
    color: const Color(0xFF101A14),
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );

  Widget _readOnly(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: Colors.white54)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _ListingVariantEditor extends StatefulWidget {
  const _ListingVariantEditor();

  @override
  State<_ListingVariantEditor> createState() => _ListingVariantEditorState();
}

class _ListingVariantEditorState extends State<_ListingVariantEditor> {
  final _sizeController = TextEditingController();
  final _colorController = TextEditingController();
  final _codeController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  String? _error;

  @override
  void dispose() {
    _sizeController.dispose();
    _colorController.dispose();
    _codeController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _save() {
    final code = _codeController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final stock = int.tryParse(_stockController.text.trim());
    if (!RegExp(r'^[A-Z0-9]+(-[A-Z0-9]+)*$').hasMatch(code)) {
      setState(
        () => _error =
            'Code must be uppercase letters, numbers, and hyphens only.',
      );
      return;
    }
    if (price == null || price <= 0 || stock == null || stock < 0) {
      setState(() => _error = 'Enter a valid variant price and stock.');
      return;
    }
    final attributes = <String, String>{
      if (_sizeController.text.trim().isNotEmpty)
        'size': _sizeController.text.trim(),
      if (_colorController.text.trim().isNotEmpty)
        'color': _colorController.text.trim(),
    };
    Navigator.pop(context, {
      'code': code,
      'attributes': attributes,
      'price': price,
      'stock': stock,
      'is_active': true,
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        20,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add business variant',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            TextField(
              controller: _sizeController,
              decoration: const InputDecoration(labelText: 'Size'),
            ),
            TextField(
              controller: _colorController,
              decoration: const InputDecoration(labelText: 'Color'),
            ),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              onChanged: (value) {
                final formatted = value.toUpperCase().replaceAll(' ', '-');
                if (formatted != value) {
                  _codeController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(
                      offset: formatted.length,
                    ),
                  );
                }
              },
              decoration: const InputDecoration(
                labelText: 'SKU / Code',
                hintText: 'TS-BLK-M',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Price'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock'),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Add variant'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CatalogProductImage extends StatelessWidget {
  const _CatalogProductImage({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: 120,
      height: 120,
      color: Colors.white10,
      child: url == null || url!.isEmpty
          ? const Icon(Icons.inventory_2_outlined, size: 40)
          : Image.network(url!, fit: BoxFit.cover),
    ),
  );
}

class _ListingMessage extends StatelessWidget {
  const _ListingMessage({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
