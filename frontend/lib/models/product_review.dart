class ReviewSnippet {
  final String source;
  final String title;
  final String snippet;
  final String? link;

  const ReviewSnippet({
    required this.source,
    required this.title,
    required this.snippet,
    this.link,
  });

  factory ReviewSnippet.fromJson(Map<String, dynamic> json) => ReviewSnippet(
        source: json['source'] as String? ?? 'Unknown',
        title: json['title'] as String? ?? '',
        snippet: json['snippet'] as String? ?? '',
        link: json['link'] as String?,
      );
}

class ReviewAnalysis {
  final double? aiRating;
  final int? satisfactionPercent;
  final String summary;
  final String verdict;
  final List<String> pros;
  final List<String> cons;
  final String sentimentLabel;

  const ReviewAnalysis({
    this.aiRating,
    this.satisfactionPercent,
    required this.summary,
    required this.verdict,
    required this.pros,
    required this.cons,
    required this.sentimentLabel,
  });

  factory ReviewAnalysis.fromJson(Map<String, dynamic> json) => ReviewAnalysis(
        aiRating: (json['aiRating'] as num?)?.toDouble(),
        satisfactionPercent: (json['satisfactionPercent'] as num?)?.toInt(),
        summary: json['summary'] as String? ?? '',
        verdict: json['verdict'] as String? ?? '',
        pros:
            (json['pros'] as List<dynamic>? ?? []).whereType<String>().toList(),
        cons:
            (json['cons'] as List<dynamic>? ?? []).whereType<String>().toList(),
        sentimentLabel: json['sentimentLabel'] as String? ?? 'Mixed',
      );
}

class ProductReviewResult {
  final List<ReviewSnippet> snippets;
  final ReviewAnalysis analysis;

  const ProductReviewResult({
    required this.snippets,
    required this.analysis,
  });

  factory ProductReviewResult.fromJson(Map<String, dynamic> json) =>
      ProductReviewResult(
        snippets: (json['snippets'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ReviewSnippet.fromJson)
            .toList(),
        analysis: ReviewAnalysis.fromJson(
            json['analysis'] as Map<String, dynamic>? ?? {}),
      );
}
