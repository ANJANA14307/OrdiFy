class InstagramConfig {
  final bool isEnabled;
  final List<String> triggerKeywords;
  final String replyText;

  const InstagramConfig({
    required this.isEnabled,
    required this.triggerKeywords,
    required this.replyText,
  });

  factory InstagramConfig.fromJson(Map<String, dynamic> json) {
    final keywords = json['trigger_keywords'];
    return InstagramConfig(
      isEnabled: json['is_enabled'] == true,
      triggerKeywords: keywords is List
          ? keywords.map((value) => value.toString()).toList()
          : const [],
      replyText: json['reply_text']?.toString() ?? '',
    );
  }
}

class InstagramConnection {
  final String status;
  final String? username;
  final String? connectedAt;

  const InstagramConnection({
    required this.status,
    required this.username,
    required this.connectedAt,
  });

  factory InstagramConnection.fromJson(Map<String, dynamic> json) {
    return InstagramConnection(
      status: json['status']?.toString() ?? 'not_connected',
      username: json['username']?.toString(),
      connectedAt: json['connected_at']?.toString(),
    );
  }
}

class RedirectStats {
  final int linkClicks;
  final int instagramOrders;

  const RedirectStats({
    required this.linkClicks,
    required this.instagramOrders,
  });

  factory RedirectStats.fromJson(Map<String, dynamic> json) {
    return RedirectStats(
      linkClicks: int.tryParse(json['link_clicks']?.toString() ?? '') ?? 0,
      instagramOrders: int.tryParse(json['orders']?.toString() ?? '') ?? 0,
    );
  }
}

class InstagramProduct {
  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final List<String> codes;
  final String? url;

  const InstagramProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.codes,
    required this.url,
  });

  factory InstagramProduct.fromJson(Map<String, dynamic> json) {
    final rawCodes = json['codes'];
    return InstagramProduct(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Product',
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
      imageUrl: json['image_url']?.toString(),
      codes: rawCodes is List
          ? rawCodes.map((code) => code.toString()).toList()
          : const [],
      url: json['url']?.toString(),
    );
  }
}

class InstagramToolsData {
  final InstagramConfig config;
  final InstagramConnection connection;
  final RedirectStats stats;
  final String? catalogLink;
  final String? whatsappLink;
  final List<InstagramProduct> products;
  final bool catalogIsPublic;
  final bool autoReplySupported;
  final bool trackingConfigured;

  const InstagramToolsData({
    required this.config,
    required this.connection,
    required this.stats,
    required this.catalogLink,
    required this.whatsappLink,
    required this.products,
    required this.catalogIsPublic,
    required this.autoReplySupported,
    required this.trackingConfigured,
  });

  factory InstagramToolsData.fromJson(Map<String, dynamic> json) {
    final rawLinks = json['links'];
    final links = rawLinks is Map
        ? Map<String, dynamic>.from(rawLinks)
        : const <String, dynamic>{};
    final rawProducts = links['products'];
    final products = rawProducts is Map
        ? rawProducts.values
              .whereType<Map>()
              .map(
                (product) => InstagramProduct.fromJson(
                  Map<String, dynamic>.from(product),
                ),
              )
              .toList()
        : <InstagramProduct>[];
    final rawStats = json['stats'];
    final rawConfig = json['config'];
    final rawConnection = json['connection'];
    final rawCatalog = json['catalog'];
    return InstagramToolsData(
      config: InstagramConfig.fromJson(
        rawConfig is Map ? Map<String, dynamic>.from(rawConfig) : const {},
      ),
      connection: InstagramConnection.fromJson(
        rawConnection is Map
            ? Map<String, dynamic>.from(rawConnection)
            : const {},
      ),
      stats: RedirectStats.fromJson(
        rawStats is Map ? Map<String, dynamic>.from(rawStats) : const {},
      ),
      catalogLink: links['catalog']?.toString(),
      whatsappLink: links['whatsapp']?.toString(),
      products: products,
      catalogIsPublic: rawCatalog is Map && rawCatalog['is_public'] == true,
      autoReplySupported: json['auto_reply_supported'] == true,
      trackingConfigured: json['tracking_configured'] == true,
    );
  }
}
