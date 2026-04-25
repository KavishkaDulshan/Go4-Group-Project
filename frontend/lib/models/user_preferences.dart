/// Learned preference profile for a signed-in user.
///
/// Built by the backend by aggregating  [category, material, style, color]
/// values across all past searches.  The frontend uses this to describe
/// what the system has learned and to display recommendations.
class UserPreferences {
  final int searchCount;
  final String? topCategory;
  final String? topMaterial;
  final String? topStyle;
  final String? topColor;
  final PriceRange? priceRange;
  final List<PreferenceEntry> allCategories;
  final List<PreferenceEntry> allMaterials;
  final List<PreferenceEntry> allStyles;
  final List<PreferenceEntry> allColors;

  const UserPreferences({
    required this.searchCount,
    this.topCategory,
    this.topMaterial,
    this.topStyle,
    this.topColor,
    this.priceRange,
    this.allCategories = const [],
    this.allMaterials = const [],
    this.allStyles = const [],
    this.allColors = const [],
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      searchCount: (json['searchCount'] as num?)?.toInt() ?? 0,
      topCategory: json['topCategory'] as String?,
      topMaterial: json['topMaterial'] as String?,
      topStyle: json['topStyle'] as String?,
      topColor: json['topColor'] as String?,
      priceRange: json['priceRange'] != null
          ? PriceRange.fromJson(json['priceRange'] as Map<String, dynamic>)
          : null,
      allCategories: _parseEntries(json['allCategories']),
      allMaterials: _parseEntries(json['allMaterials']),
      allStyles: _parseEntries(json['allStyles']),
      allColors: _parseEntries(json['allColors']),
    );
  }

  static List<PreferenceEntry> _parseEntries(dynamic raw) {
    if (raw == null) return const [];
    return (raw as List<dynamic>)
        .map((e) => PreferenceEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// True when the user has enough data for real recommendations.
  bool get hasEnoughData => searchCount >= 2;

  /// All non-null top values as a single descriptive string.
  String get preferenceSummary {
    final parts =
        [topMaterial, topStyle, topCategory].whereType<String>().toList();
    return parts.isEmpty ? 'No preferences yet' : parts.join(', ');
  }
}

// ── Preference entry ─────────────────────────────────────────────────────────

class PreferenceEntry {
  final String value;
  final int count;

  const PreferenceEntry({required this.value, required this.count});

  factory PreferenceEntry.fromJson(Map<String, dynamic> json) {
    return PreferenceEntry(
      value: json['value'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 1,
    );
  }
}

// ── Price range ──────────────────────────────────────────────────────────────

class PriceRange {
  final double? min;
  final double? max;
  final double? avg;

  const PriceRange({this.min, this.max, this.avg});

  factory PriceRange.fromJson(Map<String, dynamic> json) {
    return PriceRange(
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
      avg: (json['avg'] as num?)?.toDouble(),
    );
  }
}
