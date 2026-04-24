class SearchTag {
  final String productName;
  final String? category;
  final String? color;
  final String? material;
  final String? style;
  final String searchQuery;

  const SearchTag({
    required this.productName,
    this.category,
    this.color,
    this.material,
    this.style,
    required this.searchQuery,
  });

  factory SearchTag.fromJson(Map<String, dynamic> json) => SearchTag(
        productName: json['productName'] as String? ?? '',
        category: json['category'] as String?,
        color: json['color'] as String?,
        material: json['material'] as String?,
        style: json['style'] as String?,
        searchQuery: json['searchQuery'] as String? ?? '',
      );

  /// Returns non-null attributes as display chips, e.g. ['#Clothing','#Red','#Linen']
  List<String> get chips {
    return [
      if (category != null && category!.isNotEmpty) '#${category!}',
      if (color != null && color!.isNotEmpty) '#${color!}',
      if (material != null && material!.isNotEmpty) '#${material!}',
      if (style != null && style!.isNotEmpty) '#${style!}',
    ];
  }
}
