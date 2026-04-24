import 'product.dart';
import 'search_tag.dart';

class SearchResult {
  final String? searchId;
  final SearchTag tags;
  final List<Product> results;

  const SearchResult({
    this.searchId,
    required this.tags,
    required this.results,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        searchId: json['searchId'] as String?,
        tags: SearchTag.fromJson(json['tags'] as Map<String, dynamic>),
        results: (json['results'] as List<dynamic>)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
