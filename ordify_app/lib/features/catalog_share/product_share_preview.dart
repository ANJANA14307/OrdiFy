import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ProductSharePreview extends StatelessWidget {
  final Map<String, dynamic> product;
  final String businessName;
  final bool isCatalogPublic;

  const ProductSharePreview({
    super.key,
    required this.product,
    required this.businessName,
    this.isCatalogPublic = true,
  });

  String get _productName => product['name']?.toString() ?? 'Product';
  String get _code {
    final code = product['code']?.toString();
    if (code != null && code.isNotEmpty) return code;
    final variants = product['variants'];
    if (variants is List && variants.isNotEmpty && variants.first is Map) {
      return (variants.first as Map)['code']?.toString() ?? '';
    }
    return '';
  }

  String get _productUrl => product['product_url']?.toString() ?? '';

  String get _shareText {
    final codeLine = _code.isEmpty ? '' : '\nCode: $_code';
    final orderLine = _code.isEmpty
        ? ''
        : '\nOrder: send ORDER $_code on WhatsApp.';
    return '$_productName from $businessName — ₹${product['price'] ?? 0}'
        '$codeLine\n$_productUrl$orderLine';
  }

  Future<void> _share(BuildContext context) async {
    await SharePlus.instance.share(ShareParams(text: _shareText));
  }

  Future<void> _shareWhatsApp(BuildContext context) async {
    final uri = Uri.https('wa.me', '/', {'text': _shareText});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      await _share(context);
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _shareText));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Product details copied')));
  }

  @override
  Widget build(BuildContext context) {
    final image = product['image_url']?.toString();
    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1711),
        foregroundColor: Colors.white,
        title: Text(
          'Share Product',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: 1,
              child: image == null || image.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFF1A2A22),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFF34F087),
                        size: 58,
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
          const SizedBox(height: 16),
          Text(
            _productName,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '₹${product['price'] ?? 0}',
            style: GoogleFonts.inter(
              color: const Color(0xFF34F087),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (_code.isNotEmpty) ...[
            const SizedBox(height: 10),
            Chip(
              label: Text('Code: $_code'),
              backgroundColor: const Color(0xFF14251C),
              labelStyle: const TextStyle(
                color: Color(0xFF34F087),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SelectableText(
            _productUrl,
            style: const TextStyle(color: Colors.white70),
          ),
          if (!isCatalogPublic) ...[
            const SizedBox(height: 12),
            const Text(
              'Publish your catalog before sharing this product link.',
              style: TextStyle(
                color: Color(0xFFFFC857),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: isCatalogPublic ? () => _shareWhatsApp(context) : null,
            icon: const Icon(Icons.chat_rounded),
            label: const Text('Share on WhatsApp'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isCatalogPublic ? () => _copy(context) : null,
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy share text'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isCatalogPublic ? () => _share(context) : null,
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('More sharing options'),
          ),
          if (_code.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Order: send ORDER <CODE> on WhatsApp',
              style: TextStyle(color: Colors.white60),
            ),
          ],
        ],
      ),
    );
  }
}
