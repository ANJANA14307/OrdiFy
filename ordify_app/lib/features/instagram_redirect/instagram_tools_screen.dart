import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import 'instagram_redirect_api.dart';
import 'instagram_redirect_models.dart';

class InstagramToolsScreen extends StatefulWidget {
  const InstagramToolsScreen({super.key});

  @override
  State<InstagramToolsScreen> createState() => _InstagramToolsScreenState();
}

class _InstagramToolsScreenState extends State<InstagramToolsScreen> {
  final _keywordController = TextEditingController();
  final _replyController = TextEditingController();
  InstagramToolsData? _data;
  List<String> _keywords = [];
  String? _selectedProductId;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isConnecting = false;
  bool _autoReplyEnabled = false;
  bool _permissionNeeded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await instagramRedirectApi.getTools();
      if (!mounted) return;
      setState(() {
        _data = data;
        _permissionNeeded = data.connection.status == 'permission_needed';
        _keywords = List.of(data.config.triggerKeywords);
        _replyController.text = data.config.replyText;
        _autoReplyEnabled = data.config.isEnabled;
        if (data.products.isNotEmpty &&
            !data.products.any((product) => product.id == _selectedProductId)) {
          _selectedProductId = data.products.first.id;
        }
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _error = null;
    });
    try {
      await instagramRedirectApi.connect();
      if (!mounted) return;
      await _load();
      if (mounted && _data?.connection.status == 'connected') {
        _showMessage('Instagram connected');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(error);
        _permissionNeeded =
            error is DioException &&
            (error.response?.statusCode == 403 ||
                error.response?.statusCode == 503);
        _isConnecting = false;
      });
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _save({bool? enabled}) async {
    final data = _data;
    if (data == null) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final saved = await instagramRedirectApi.saveConfig(
        InstagramConfig(
          isEnabled: enabled ?? _autoReplyEnabled,
          triggerKeywords: _keywords,
          replyText: _replyController.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _data = saved;
        _autoReplyEnabled = saved.config.isEnabled;
        _keywords = List.of(saved.config.triggerKeywords);
        _isSaving = false;
      });
      _showMessage(
        enabled == null
            ? 'Instagram tools saved'
            : 'Auto-reply settings updated',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(error);
        _isSaving = false;
      });
    }
  }

  Future<void> _copy(String? link, String label) async {
    if (link == null || link.isEmpty) {
      _showMessage(
        'Publish your catalog, configure WhatsApp, and set PUBLIC_API_BASE_URL on the backend',
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) _showMessage('$label copied');
  }

  Future<void> _openLink(String? link) async {
    if (link == null || link.isEmpty) return;
    final opened = await launchUrl(
      Uri.parse(link),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) _showMessage('Could not open link');
  }

  void _addKeyword() {
    final keyword = _keywordController.text.trim().toLowerCase();
    if (keyword.isEmpty) return;
    if (_keywords.contains(keyword)) {
      _keywordController.clear();
      return;
    }
    if (_keywords.length >= 20) {
      _showMessage('You can add up to 20 trigger keywords');
      return;
    }
    setState(() {
      _keywords.add(keyword);
      _keywordController.clear();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map && responseData['detail'] != null) {
        final detail = responseData['detail'];
        if (detail is String) return detail;
        if (detail is List) {
          return detail
              .whereType<Map>()
              .map((item) => item['msg']?.toString())
              .whereType<String>()
              .join('\n');
        }
      }
      if (error.response == null) {
        return 'Could not reach the OrdiFy API. Check that the backend is running and try again.';
      }
      return 'Instagram tools request failed (HTTP ${error.response?.statusCode}). Please try again.';
    }
    return 'Instagram tools could not be loaded. Please try again.';
  }

  String _replyPreview(InstagramToolsData data) => _replyController.text
      .replaceAll(
        '{catalog_link}',
        data.catalogLink ?? '[catalog link unavailable]',
      )
      .replaceAll(
        '{whatsapp_link}',
        data.whatsappLink ?? '[WhatsApp link unavailable]',
      );

  String _caption(InstagramToolsData data, InstagramProduct product) {
    final code = product.codes.isEmpty
        ? 'Code not set'
        : 'Code: ${product.codes.first}';
    final catalogLink =
        product.url ?? data.catalogLink ?? '[catalog link unavailable]';
    final whatsappLink = data.whatsappLink ?? '[WhatsApp link unavailable]';
    return 'Discover ${product.name} ✨\n'
        '$code\n'
        'Price: ₹${product.price.toStringAsFixed(2)}\n'
        'Shop: $catalogLink\n'
        'Order via WhatsApp: $whatsappLink';
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      appBar: AppBar(
        title: const Text('Instagram Tools'),
        backgroundColor: const Color(0xFF07120C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : data == null
          ? _ScreenError(
              message: _error ?? 'Could not load Instagram tools',
              onRetry: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _connectionCard(data),
                  const SizedBox(height: 12),
                  _bioLinkCard(data),
                  const SizedBox(height: 12),
                  _autoReplyCard(data),
                  const SizedBox(height: 12),
                  _captionCard(data),
                  const SizedBox(height: 12),
                  _statsCard(data),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _connectionCard(InstagramToolsData data) {
    final status = _permissionNeeded
        ? 'permission_needed'
        : data.connection.status;
    final (label, color, help) = switch (status) {
      'connected' => (
        'CONNECTED',
        const Color(0xFF34F087),
        data.connection.username == null
            ? 'Instagram is connected.'
            : '@${data.connection.username}',
      ),
      'permission_needed' => (
        'PERMISSION NEEDED',
        const Color(0xFFFFC857),
        'Instagram API access or required messaging permissions are not configured.',
      ),
      _ => (
        'NOT CONNECTED',
        const Color(0xFFFFC857),
        'Connect the Instagram account used by this business.',
      ),
    };
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.camera_alt_rounded,
                color: Color(0xFFE59AFF),
                size: 25,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Instagram connection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _Badge(label: label, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(help, style: const TextStyle(color: Colors.white60)),
          if (status != 'connected') ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isConnecting ? null : _connect,
              icon: _isConnecting
                  ? const SizedBox(
                      height: 17,
                      width: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link_rounded),
              label: Text(
                _isConnecting ? 'Connecting...' : 'Connect Instagram',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bioLinkCard(InstagramToolsData data) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bio link',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use backend-tracked redirects to send visitors to your catalog or WhatsApp.',
            style: TextStyle(color: Colors.white60, height: 1.4),
          ),
          if (!data.catalogIsPublic) ...[
            const SizedBox(height: 10),
            const Text(
              'Publish a catalog to enable tracked links.',
              style: TextStyle(color: Color(0xFFFFC857)),
            ),
          ],
          if (!data.trackingConfigured) ...[
            const SizedBox(height: 10),
            const Text(
              'Tracked links are unavailable. Set PUBLIC_API_BASE_URL in backend/.env and restart the backend.',
              style: TextStyle(color: Color(0xFFFFC857)),
            ),
          ],
          const SizedBox(height: 12),
          _LinkRow(
            title: 'Catalog link',
            link: data.catalogLink,
            onCopy: () => _copy(data.catalogLink, 'Catalog link'),
            onOpen: () => _openLink(data.catalogLink),
          ),
          const SizedBox(height: 8),
          _LinkRow(
            title: 'WhatsApp link',
            link: data.whatsappLink,
            onCopy: () => _copy(data.whatsappLink, 'WhatsApp link'),
            onOpen: () => _openLink(data.whatsappLink),
          ),
        ],
      ),
    );
  }

  Widget _autoReplyCard(InstagramToolsData data) {
    final connected =
        !_permissionNeeded && data.connection.status == 'connected';
    final supported = data.autoReplySupported;
    final enabled = _autoReplyEnabled && connected && supported;
    final message = !connected
        ? 'Connect Instagram to enable.'
        : !supported
        ? 'Configure Instagram webhook and Meta permissions on the backend to enable replies.'
        : 'Replies only redirect customers to the catalog and WhatsApp. Instagram does not create orders.';
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Auto-reply setup',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (!connected || !supported)
                const _Badge(
                  label: 'CONNECT TO ENABLE',
                  color: Color(0xFFFFC857),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            activeThumbColor: const Color(0xFF34F087),
            title: const Text(
              'Enable keyword replies',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            onChanged: !connected || !supported || _isSaving
                ? null
                : (value) => _save(enabled: value),
          ),
          const SizedBox(height: 5),
          const Text(
            'Trigger keywords',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 4,
            children: [
              for (final keyword in _keywords)
                InputChip(
                  label: Text(keyword),
                  onDeleted: () => setState(() => _keywords.remove(keyword)),
                  backgroundColor: const Color(0xFF173321),
                  labelStyle: const TextStyle(color: Colors.white),
                  deleteIconColor: Colors.white70,
                ),
              if (_keywords.isEmpty)
                const Text(
                  'Add at least one keyword.',
                  style: TextStyle(color: Colors.white54),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _addKeyword(),
                  decoration: InputDecoration(
                    hintText: 'Add a keyword',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _addKeyword,
                icon: const Icon(Icons.add_circle_rounded),
                color: const Color(0xFF34F087),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Reply text',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _replyController,
            minLines: 3,
            maxLines: 5,
            maxLength: 1000,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, height: 1.4),
            decoration: InputDecoration(
              helperText: 'Required: {catalog_link} and {whatsapp_link}',
              helperStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF07120C),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              _replyPreview(data),
              style: const TextStyle(color: Colors.white, height: 1.45),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : () => _save(),
              icon: _isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'Saving...' : 'Save auto-reply settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _captionCard(InstagramToolsData data) {
    final product = data.products
        .where((item) => item.id == _selectedProductId)
        .firstOrNull;
    final hasCodedProduct = data.products.any((item) => item.codes.isNotEmpty);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Story/post caption',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Generate a ready-to-copy product caption. Instagram is for discovery; send orders to WhatsApp.',
            style: TextStyle(color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (data.products.isEmpty)
            const Text(
              'Publish your catalog with selected active products to generate captions.',
              style: TextStyle(color: Color(0xFFFFC857)),
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedProductId,
              dropdownColor: const Color(0xFF101A14),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Product',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              items: [
                for (final item in data.products)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _selectedProductId = value),
            ),
            const SizedBox(height: 10),
            if (product != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFF07120C),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  _caption(data, product),
                  style: const TextStyle(color: Colors.white, height: 1.5),
                ),
              ),
            if (!hasCodedProduct) ...[
              const SizedBox(height: 8),
              const Text(
                'Add a product variant code to include a usable order code in the caption.',
                style: TextStyle(color: Color(0xFFFFC857), fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: product == null
                  ? null
                  : () => _copy(_caption(data, product), 'Caption'),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy caption'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statsCard(InstagramToolsData data) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Redirect stats',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        if (data.stats.linkClicks == 0 && data.stats.instagramOrders == 0)
          const Text(
            'No Instagram redirect activity yet. Link clicks and Instagram DM orders will appear here.',
            style: TextStyle(color: Colors.white60, height: 1.45),
          )
        else
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Link clicks',
                  value: '${data.stats.linkClicks}',
                  icon: Icons.ads_click_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(
                  label: 'Instagram orders',
                  value: '${data.stats.instagramOrders}',
                  icon: Icons.receipt_long_rounded,
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF101A14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
    ),
    child: child,
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
    ),
  );
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.title,
    required this.link,
    required this.onCopy,
    required this.onOpen,
  });
  final String title;
  final String? link;
  final VoidCallback onCopy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: Colors.black26,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                link ?? 'Not available',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: link == null ? null : onCopy,
          tooltip: 'Copy link',
          icon: const Icon(Icons.copy_rounded, color: Color(0xFF34F087)),
        ),
        IconButton(
          onPressed: link == null ? null : onOpen,
          tooltip: 'Open link',
          icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF34F087)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    ),
  );
}

class _ScreenError extends StatelessWidget {
  const _ScreenError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
