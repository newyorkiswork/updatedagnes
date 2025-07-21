class ShoppingResult {
  final String type; // 'ad' or 'result'
  final String title;
  final String price;
  final String seller;
  final String rating;
  final String reviews;
  final String? offers;
  final String thumbnail;
  final String link;
  final String? productId; // Product ID for price comparison
  final String? serpapiProductApi; // SerpAPI product API URL for live pricing

  ShoppingResult({
    required this.type,
    required this.title,
    required this.price,
    required this.seller,
    required this.rating,
    required this.reviews,
    this.offers,
    required this.thumbnail,
    required this.link,
    this.productId,
    this.serpapiProductApi,
  });

  factory ShoppingResult.fromMap(Map<String, dynamic> map) {
    return ShoppingResult(
      type: map['type'] ?? '',
      title: map['title'] ?? 'No title',
      price: map['price'] ?? 'No price',
      seller: map['seller'] ?? 'No seller',
      rating: map['rating'] ?? 'No rating',
      reviews: map['reviews'] ?? 'No reviews',
      offers: map['offers'],
      thumbnail: map['thumbnail'] ?? '',
      link: map['link'] ?? '',
      productId: map['product_id'] ?? map['productId'],
      serpapiProductApi: map['serpapi_product_api'],
    );
  }

  bool get isAd => type == 'ad';
  bool get isOrganicResult => type == 'result';

  @override
  String toString() {
    return 'ShoppingResult(type: $type, title: $title, price: $price, seller: $seller)';
  }
} 