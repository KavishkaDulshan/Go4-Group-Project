class Product {
  final String title;
  final String? price;
  final String? originalPrice;
  final String? link;
  final String? imageUrl;
  final String? thumbnail;
  final String? source;
  final double? rating;
  final int? ratingCount;
  final String? delivery;
  final int? offers;
  final List<String> extensions;

  const Product({
    required this.title,
    this.price,
    this.originalPrice,
    this.link,
    this.imageUrl,
    this.thumbnail,
    this.source,
    this.rating,
    this.ratingCount,
    this.delivery,
    this.offers,
    this.extensions = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        title:         json['title']         as String? ?? 'Unknown Product',
        price:         json['price']         as String?,
        originalPrice: json['originalPrice'] as String?,
        link:          json['link']          as String?,
        imageUrl:      json['imageUrl']      as String?,
        thumbnail:     json['thumbnail']     as String?,
        source:        json['source']        as String?,
        rating:        (json['rating']       as num?)?.toDouble(),
        ratingCount:   json['ratingCount']   as int?,
        delivery:      json['delivery']      as String?,
        offers:        json['offers']        as int?,
        extensions:    (json['extensions']   as List<dynamic>?)
                           ?.map((e) => e as String)
                           .toList() ??
                       const [],
      );

  /// Best display image: prefer thumbnail (CDN), fall back to imageUrl
  String? get displayImage => thumbnail ?? imageUrl;
}
