class SearchFilterOption {
  final String value;
  final String label;

  const SearchFilterOption({required this.value, required this.label});

  factory SearchFilterOption.fromJson(Map<String, dynamic> json) =>
      SearchFilterOption(
        value: json['value'] as String? ?? '',
        label: json['label'] as String? ?? '',
      );
}

/// A single AI-generated filter with currently selected value(s).
///
/// Chips filters support multi-select via [selectedValues].
/// Dropdown filters are single-select; [selectedValues] holds 0 or 1 entry.
class SearchFilter {
  final String key;
  final String label;

  /// 'dropdown' or 'chips'
  final String type;
  final List<SearchFilterOption> options;
  final String? defaultValue;

  /// Mutable — holds all currently selected values.
  /// Multi-select for chips; 0-or-1 entry for dropdown.
  List<String> selectedValues;

  /// Convenience getter: first selected value, or null if none selected.
  String? get selectedValue =>
      selectedValues.isEmpty ? null : selectedValues.first;

  SearchFilter({
    required this.key,
    required this.label,
    required this.type,
    required this.options,
    this.defaultValue,
    List<String>? selectedValues,
  }) : selectedValues = selectedValues ??
            (defaultValue != null ? [defaultValue] : <String>[]);

  factory SearchFilter.fromJson(Map<String, dynamic> json) {
    final opts = (json['options'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SearchFilterOption.fromJson)
        .toList();

    final defaultVal = json['defaultValue'] as String?;
    return SearchFilter(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: json['type'] as String? ?? 'chips',
      options: opts,
      defaultValue: defaultVal,
      selectedValues: defaultVal != null ? [defaultVal] : <String>[],
    );
  }
}

/// Result returned by the /analyze endpoint.
class AnalyzeResult {
  final Map<String, dynamic> tags;
  final List<SearchFilter> filters;

  const AnalyzeResult({required this.tags, required this.filters});

  factory AnalyzeResult.fromJson(Map<String, dynamic> json) => AnalyzeResult(
        tags: json['tags'] as Map<String, dynamic>? ?? {},
        filters: (json['filters'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(SearchFilter.fromJson)
            .toList(),
      );
}
