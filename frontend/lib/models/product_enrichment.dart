class ProductSpec {
  final String key;
  final String value;
  const ProductSpec({required this.key, required this.value});

  factory ProductSpec.fromJson(Map<String, dynamic> json) => ProductSpec(
        key: json['key'] as String? ?? '',
        value: json['value'] as String? ?? '',
      );
}

class ProductEnrichment {
  final String description;
  final List<ProductSpec> specifications;
  final List<String> features;
  final String? compatibility;
  final String? bestFor;

  const ProductEnrichment({
    required this.description,
    required this.specifications,
    required this.features,
    this.compatibility,
    this.bestFor,
  });

  factory ProductEnrichment.fromJson(Map<String, dynamic> json) =>
      ProductEnrichment(
        description: json['description'] as String? ?? '',
        specifications: (json['specifications'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ProductSpec.fromJson)
            .where((s) => s.key.isNotEmpty && s.value.isNotEmpty)
            .toList(),
        features: (json['features'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
        compatibility: json['compatibility'] as String?,
        bestFor: json['bestFor'] as String?,
      );
}
