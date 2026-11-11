import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'shared_catalog_api.dart';
import 'shared_catalog_models.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  List<BusinessListing> _listings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final listings = await sharedCatalogApi.myListings();
      if (!mounted) return;
      setState(() {
        _listings = listings;
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

  Future<void> _edit(BusinessListing listing) async {
    final values = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101A14),
      builder: (_) => _EditListingSheet(listing: listing),
    );
    if (values == null) return;
    try {
      final updated = await sharedCatalogApi.updateListing(listing.id, values);
      if (!mounted) return;
      setState(() {
        _listings = _listings
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
      });
      _message('Listing updated');
    } catch (error) {
      if (!mounted) return;
      _message(sharedCatalogError(error));
    }
  }

  Future<void> _toggleActive(BusinessListing listing, bool active) async {
    try {
      final updated = await sharedCatalogApi.updateListing(listing.id, {
        'is_active': active,
      });
      if (!mounted) return;
      setState(() {
        _listings = _listings
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
      });
      _message(active ? 'Listing enabled' : 'Listing disabled');
    } catch (error) {
      if (!mounted) return;
      _message(sharedCatalogError(error));
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
      title: const Text('My shared catalog listings'),
      backgroundColor: const Color(0xFF07120C),
      foregroundColor: Colors.white,
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => context.push('/shared-catalog/search'),
      icon: const Icon(Icons.search_rounded),
      label: const Text('Find product'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _ListingsMessage(
            title: 'Could not load listings',
            message: _error!,
            onRetry: _load,
          )
        : _listings.isEmpty
        ? _ListingsMessage(
            title: 'No shared catalog listings',
            message:
                'Find a product in the OrdiFy catalog and set your own price and stock.',
            onRetry: () => context.push('/shared-catalog/search'),
            retryLabel: 'Find in OrdiFy catalog',
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._listings.map(
                  (listing) => Card(
                    color: const Color(0xFF101A14),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _ListingImage(
                                url: listing.product.images.firstOrNull,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      listing.product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      [
                                        if (listing.product.brand?.isNotEmpty ==
                                            true)
                                          listing.product.brand!,
                                        listing.product.category,
                                      ].join(' • '),
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Your price ₹${listing.price.toStringAsFixed(2)} • Your stock ${listing.stock}',
                                      style: const TextStyle(
                                        color: Color(0xFF34F087),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _edit(listing),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit your listing',
                              ),
                            ],
                          ),
                          if (listing.variants.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: listing.variants
                                  .map(
                                    (variant) => Chip(
                                      label: Text(
                                        '${variant['code']} • ${variant['stock']} in stock',
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          if (listing.deliveryOverride != null)
                            Text(
                              'Your delivery override: ₹${listing.deliveryOverride!['fee']}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          if (listing.returnPolicyOverride != null)
                            Text(
                              'Your return window: ${listing.returnPolicyOverride!['return_window_days']} days',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              listing.isActive ? 'Listed' : 'Unlisted',
                            ),
                            value: listing.isActive,
                            onChanged: (value) => _toggleActive(listing, value),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
}

class _EditListingSheet extends StatefulWidget {
  const _EditListingSheet({required this.listing});
  final BusinessListing listing;

  @override
  State<_EditListingSheet> createState() => _EditListingSheetState();
}

class _EditListingSheetState extends State<_EditListingSheet> {
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.listing.price.toString(),
    );
    _stockController = TextEditingController(
      text: widget.listing.stock.toString(),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _save() {
    final price = double.tryParse(_priceController.text.trim());
    final stock = int.tryParse(_stockController.text.trim());
    if (price == null || price <= 0 || stock == null || stock < 0) {
      setState(() => _error = 'Enter a positive price and non-negative stock.');
      return;
    }
    Navigator.pop(context, {'price': price, 'stock': stock});
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Edit your ${widget.listing.product.name} listing',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Your price'),
          ),
          TextField(
            controller: _stockController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Your stock'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
    ),
  );
}

class _ListingImage extends StatelessWidget {
  const _ListingImage({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 58,
      height: 58,
      color: Colors.white10,
      child: url == null || url!.isEmpty
          ? const Icon(Icons.inventory_2_outlined)
          : Image.network(url!, fit: BoxFit.cover),
    ),
  );
}

class _ListingsMessage extends StatelessWidget {
  const _ListingsMessage({
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Retry',
  });
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 44,
            color: Color(0xFF34F087),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    ),
  );
}
