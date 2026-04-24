import 'product.dart';

/// A [Product] the user has saved to their wishlist, with a timestamp.
class WishlistItem {
  final Product product;
  final DateTime savedAt;

  const WishlistItem({required this.product, required this.savedAt});

  Map<String, dynamic> toJson() => {
        'title': product.title,
        'price': product.price,
        'originalPrice': product.originalPrice,
        'link': product.link,
        'imageUrl': product.imageUrl,
        'thumbnail': product.thumbnail,
        'source': product.source,
        'rating': product.rating,
        'ratingCount': product.ratingCount,
        'delivery': product.delivery,
        'offers': product.offers,
        'extensions': product.extensions,
        'savedAt': savedAt.toIso8601String(),
      };

  factory WishlistItem.fromJson(Map<String, dynamic> json) => WishlistItem(
        product: Product.fromJson(json),
        savedAt: json['savedAt'] != null
            ? DateTime.tryParse(json['savedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}
