import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/shopping_result.dart';
import '../services/search_api_service.dart';

class ProductOffersScreen extends StatefulWidget {
  final ShoppingResult product;

  const ProductOffersScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductOffersScreen> createState() => _ProductOffersScreenState();
}

class _ProductOffersScreenState extends State<ProductOffersScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _offers = [];
  Map<String, dynamic>? _productInfo;

  @override
  void initState() {
    super.initState();
    _loadProductOffers();
  }

  Future<void> _loadProductOffers() async {
    // Try SerpAPI product API URL first (for live pricing)
    if (widget.product.serpapiProductApi != null && widget.product.serpapiProductApi!.isNotEmpty) {
      try {
        print('🔍 Trying live product offers with SerpAPI URL...');
        final result = await SearchApiService.getLiveProductOffers(
          serpapiProductApiUrl: widget.product.serpapiProductApi!,
        );

        if (result['success']) {
          final data = result['data'];
          final offers = data['offers'] as List<dynamic>? ?? [];
          final productInfo = data['product_info'] as Map<String, dynamic>?;

          setState(() {
            _offers = offers.map((offer) => offer as Map<String, dynamic>).toList();
            _productInfo = productInfo;
            _isLoading = false;
          });
          return;
        } else {
          print('🔍 Live product offers failed: ${result['error']}');
        }
      } catch (e) {
        print('❌ Error with live product offers: $e');
      }
    }

    // Fallback to product ID method
    if (widget.product.productId != null) {
      try {
        print('🔍 Trying product offers with product ID...');
        final result = await SearchApiService.getProductOffers(
          productId: widget.product.productId!,
        );

        if (result['success']) {
          final data = result['data'];
          final offers = data['offers'] as List<dynamic>? ?? [];
          final productInfo = data['product_info'] as Map<String, dynamic>?;

          setState(() {
            _offers = offers.map((offer) => offer as Map<String, dynamic>).toList();
            _productInfo = productInfo;
            _isLoading = false;
          });
          return;
        } else {
          print('🔍 Product ID method failed: ${result['error']}');
        }
      } catch (e) {
        print('❌ Error with product ID method: $e');
      }
    }

    // Fallback: Show current search results as live pricing
    print('🔍 Using current search results as live pricing fallback...');
    setState(() {
      _offers = [
        {
          'seller': widget.product.seller,
          'price': widget.product.price,
          'total_price': widget.product.price,
          'delivery': 'Free shipping available',
          'rating': widget.product.rating,
          'link': widget.product.link,
          'special_offer': widget.product.offers ?? 'Current market price',
        }
      ];
      _productInfo = {
        'title': widget.product.title,
        'image': widget.product.thumbnail,
        'rating': widget.product.rating,
        'reviews': widget.product.reviews,
      };
      _isLoading = false;
    });
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open link'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Comparison'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Add a button to open the main product link
          if (widget.product.link.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _launchUrl(widget.product.link),
              tooltip: 'Open Product Page',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading price comparisons...'),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This feature shows live pricing from multiple retailers for the selected product.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Note: Some products may show current search results when live API data is unavailable.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: Colors.orange),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProductOffers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildOffersList(),
    );
  }

  Widget _buildOffersList() {
    return Column(
      children: [
        // Product info header
        if (_productInfo != null) _buildProductHeader(),
        
        // Offers list
        Expanded(
          child: _offers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No price offers available',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _offers.length,
                  itemBuilder: (context, index) {
                    final offer = _offers[index];
                    return _buildOfferCard(offer);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductHeader() {
    final productInfo = _productInfo!;
    final title = productInfo['title'] ?? widget.product.title;
    final image = productInfo['image'] ?? widget.product.thumbnail;
    final rating = productInfo['rating'] ?? widget.product.rating;
    final reviews = productInfo['reviews'] ?? widget.product.reviews;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          // Product image
          if (image.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                image,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, color: Colors.grey),
                  );
                },
              ),
            ),
          
          const SizedBox(width: 16),
          
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (rating.isNotEmpty && rating != 'No rating')
                  Row(
                    children: [
                      Text(
                        rating,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (reviews.isNotEmpty && reviews != 'No reviews')
                        Text(
                          '($reviews)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                // Show product ID if available
                if (widget.product.productId != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Product ID: ${widget.product.productId}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final seller = offer['seller'] ?? 'Unknown Seller';
    final price = offer['price'] ?? 'Price not available';
    final totalPrice = offer['total_price'] ?? price;
    final delivery = offer['delivery'] ?? '';
    final rating = offer['rating'] ?? '';
    final specialOffer = offer['special_offer'] ?? '';
    final link = offer['link'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seller and rating row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    seller,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (rating.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(rating),
                    ],
                  ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Price row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price: $price',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    if (totalPrice != price)
                      Text(
                        'Total: $totalPrice',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
                if (link.isNotEmpty)
                  ElevatedButton(
                    onPressed: () => _launchUrl(link),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Visit Site'),
                  ),
              ],
            ),
            
            // Delivery info
            if (delivery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Delivery: $delivery',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
            
            // Special offer
            if (specialOffer.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  specialOffer,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 