import 'product.dart';
import 'search_tag.dart';

class HistoryItem {
  final String searchId;
  final SearchTag tags;
  final List<Product> results;
  final DateTime createdAt;

  const HistoryItem({
    required this.searchId,
    required this.tags,
    required this.results,
    required this.createdAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        searchId: json['searchId'] as String,
        tags: SearchTag.fromJson(json['tags'] as Map<String, dynamic>),
        results: (json['results'] as List<dynamic>)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
