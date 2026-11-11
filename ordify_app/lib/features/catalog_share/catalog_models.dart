class CatalogSettings {
  final String slug;
  final bool isPublic;
  final List<String> selectedProductIds;
  final List<String> selectedListingIds;
  final String url;

  const CatalogSettings({
    required this.slug,
    required this.isPublic,
    required this.selectedProductIds,
    this.selectedListingIds = const [],
    required this.url,
  });

  factory CatalogSettings.fromJson(Map<String, dynamic> json) {
    final selected = json['selected_product_ids'];
    final selectedListings = json['selected_listing_ids'];
    return CatalogSettings(
      slug: json['slug']?.toString() ?? '',
      isPublic: json['is_public'] == true,
      selectedProductIds: selected is List
          ? selected.map((value) => value.toString()).toList()
          : const [],
      selectedListingIds: selectedListings is List
          ? selectedListings.map((value) => value.toString()).toList()
          : const [],
      url: json['url']?.toString() ?? '',
    );
  }
}
