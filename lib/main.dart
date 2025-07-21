import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'services/search_api_service.dart';
import 'models/shopping_result.dart';
import 'widgets/camera_screen.dart';
import 'widgets/product_offers_screen.dart';

void main() {
  runApp(const SearchApiTestApp());
}

class SearchApiTestApp extends StatelessWidget {
  const SearchApiTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SearchAPI Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SearchTestPage(),
    );
  }
}

class SearchTestPage extends StatefulWidget {
  const SearchTestPage({super.key});

  @override
  State<SearchTestPage> createState() => _SearchTestPageState();
}

class _SearchTestPageState extends State<SearchTestPage> {
  final TextEditingController _searchController = TextEditingController();
  String _apiResponse = 'No search performed yet';
  bool _isLoading = false;
  List<ShoppingResult> _results = [];
  File? _capturedImage;

  @override
  void initState() {
    super.initState();
    _searchController.text = "🔥 TEST SEARCH QUERY 🔥";
  }

  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
      _apiResponse = 'Searching...';
      _results = [];
    });

    try {
      final query = _searchController.text.trim();
      
      if (query.isEmpty) {
        setState(() {
          _apiResponse = 'Please enter a search query';
          _isLoading = false;
        });
        return;
      }

      final result = await SearchApiService.searchGoogleShopping(query: query);
      
      if (result['success']) {
        final data = result['data'];
        final parsedResults = SearchApiService.parseShoppingResults(data);
        
        setState(() {
          _results = parsedResults.map((map) => ShoppingResult.fromMap(map)).toList();
          _apiResponse = '✅ Found ${_results.length} results';
          _isLoading = false;
        });
        
        print('📊 Found ${_results.length} results');
      } else {
        setState(() {
          _apiResponse = '❌ ${result['error']}';
          if (result['details'] != null) {
            _apiResponse += '\n\nDetails: ${result['details']}';
          }
          _isLoading = false;
        });
      }
      
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _apiResponse = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _searchByImage(File imageFile) async {
    setState(() {
      _isLoading = true;
      _apiResponse = 'Analyzing image...';
      _results = [];
      _capturedImage = imageFile;
    });

    try {
      // Try to analyze the image
      final imageResult = await SearchApiService.searchByImage(imageFile);
      
      if (imageResult['success']) {
        final imageData = imageResult['data'];
        
        // Check if this is a fallback search
        if (imageData['fallback_search'] == true) {
          // Handle fallback search - show suggested categories
          final suggestedSearches = imageData['suggested_searches'] as List<dynamic>? ?? [];
          final currentSearch = imageData['current_search'] as String? ?? '';
          final parsedResults = SearchApiService.parseShoppingResults(imageData);
          
          setState(() {
            _results = parsedResults.map((map) => ShoppingResult.fromMap(map)).toList();
            _apiResponse = '📸 Image captured! Here are some results. Try searching for: ${suggestedSearches.take(3).join(', ')}';
            _isLoading = false;
          });
          
          // Update search field with a relevant suggestion
          if (currentSearch.isNotEmpty) {
            _searchController.text = currentSearch;
          }
          
        } else {
          // Check for smart fallback first
          if (imageData['smart_fallback'] == true) {
            final usedQuery = imageData['used_query'] as String? ?? '';
            final parsedResults = SearchApiService.parseShoppingResults(imageData);
            
            setState(() {
              _results = parsedResults.map((map) => ShoppingResult.fromMap(map)).toList();
              _apiResponse = '✅ Found ${_results.length} results using: "$usedQuery"';
              _isLoading = false;
            });
            
            if (usedQuery.isNotEmpty) {
              _searchController.text = usedQuery;
            }
            
            print('📊 Found ${_results.length} results using smart fallback: $usedQuery');
            return;
          }
          
          // Check for OCR extracted text first
          final ocrExtractedText = imageData['ocr_extracted_text'] as String?;
          final extractedProduct = imageData['extracted_product'] as String?;
          final extractedQuery = imageData['extracted_query'] as String?;
          final usedQuery = imageData['used_query'] as String?;
          final manualSearchNeeded = imageData['manual_search_needed'] as bool? ?? false;
          
                      try {
              // Parse the shopping results from the image search
              final parsedResults = SearchApiService.parseShoppingResults(imageData);
              
              // Priority order: OCR extracted query > extracted product > extracted query > used query
              String searchQuery = '';
              String responseMessage = '';
              
              if (extractedQuery != null && extractedQuery.isNotEmpty) {
                searchQuery = extractedQuery;
                responseMessage = '✅ Found ${_results.length} results for "$extractedQuery"';
                print('📊 Found ${_results.length} results for extracted query: $extractedQuery');
              } else if (extractedProduct != null && extractedProduct.isNotEmpty) {
                searchQuery = extractedProduct;
                responseMessage = '✅ Found ${_results.length} results for "$extractedProduct"';
                print('📊 Found ${_results.length} results for extracted product: $extractedProduct');
              } else if (usedQuery != null && usedQuery.isNotEmpty) {
                searchQuery = usedQuery;
                responseMessage = '✅ Found ${_results.length} results using: "$usedQuery"';
                print('📊 Found ${_results.length} results using query: $usedQuery');
              }
              
              // Update the search field with the detected text
              if (searchQuery.isNotEmpty) {
                _searchController.text = searchQuery;
                
                setState(() {
                  _results = parsedResults.map((map) => ShoppingResult.fromMap(map)).toList();
                  _apiResponse = responseMessage;
                  _isLoading = false;
                });
              } else if (manualSearchNeeded && ocrExtractedText != null && ocrExtractedText.isNotEmpty) {
                // Show OCR text and prompt for manual search
                final productQuery = SearchApiService.extractProductQueryFromText(ocrExtractedText);
                _searchController.text = productQuery;
                
                setState(() {
                  _results = [];
                  _apiResponse = '📸 Text extracted: "$productQuery". Please search manually or refine the query.';
                  _isLoading = false;
                });
                
                print('📸 OCR extracted text: "$ocrExtractedText"');
                print('📸 Product query: "$productQuery"');
              } else {
                setState(() {
                  _apiResponse = '❌ Could not identify product in image';
                  _isLoading = false;
                });
              }
            } catch (e) {
              print('❌ Error parsing results: $e');
              setState(() {
                _apiResponse = '❌ Error processing results: $e';
                _isLoading = false;
              });
            }
        }
      } else {
        setState(() {
          _apiResponse = '❌ Image analysis failed: ${imageResult['error']}';
          _isLoading = false;
        });
      }
      
    } catch (e) {
      print('❌ Image search error: $e');
      setState(() {
        _apiResponse = '❌ Image search error: $e';
        _isLoading = false;
      });
    }
  }

  void _openCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          onImageCaptured: _searchByImage,
        ),
      ),
    );
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('🔥 SEARCHAPI TEST APP 🔥'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Search Query',
                      hintText: 'Enter product to search...',
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _performSearch,
                  child: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Search'),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Camera button row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _openCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Scan Product'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Show captured image if available
            if (_capturedImage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📸 Scanned Image:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _capturedImage!,
                        height: 200, // Reduced from 300 to 200
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap image to view full size',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            
            if (_results.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Found ${_results.length} results',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Results section - now scrollable within the main scroll view
            if (_results.isNotEmpty)
              Column(
                children: [
                  // Results header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Found ${_results.length} results',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            // Try a direct search for ONE A DAY MEN'S
                            _searchController.text = "ONE A DAY MEN'S multivitamin";
                            _performSearch();
                          },
                          child: const Text('Try Direct Search'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Results list - no fixed height, will expand naturally
                  ...List.generate(_results.length, (index) {
                    final result = _results[index];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: result.thumbnail.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                result.thumbnail,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: result.isAd ? Colors.orange.shade100 : Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      result.isAd ? Icons.ads_click : Icons.shopping_bag,
                                      color: result.isAd ? Colors.orange : Colors.blue,
                                    ),
                                  );
                                },
                              ),
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: result.isAd ? Colors.orange.shade100 : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                result.isAd ? Icons.ads_click : Icons.shopping_bag,
                                color: result.isAd ? Colors.orange : Colors.blue,
                              ),
                            ),
                        title: Text(
                          result.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Price: ${result.price}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                            Text('Seller: ${result.seller}'),
                            if (result.rating != 'No rating')
                              Row(
                                children: [
                                  Icon(Icons.star, size: 16, color: Colors.amber),
                                  Text(' ${result.rating} (${result.reviews} reviews)'),
                                ],
                              ),
                            if (result.offers != null && result.offers!.isNotEmpty)
                              Text(
                                'Offers: ${result.offers}',
                                style: const TextStyle(color: Colors.blue),
                              ),
                            if (result.productId != null)
                              Text(
                                'Product ID: ${result.productId}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontFamily: 'monospace',
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (result.link.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.open_in_new, size: 20),
                                onPressed: () => _launchUrl(result.link),
                                tooltip: 'Open Product Page',
                              ),
                            if (result.isAd)
                              const Chip(
                                label: Text('AD'),
                                backgroundColor: Colors.orange,
                                labelStyle: TextStyle(color: Colors.white),
                              ),
                          ],
                        ),
                        onTap: () {
                          // Navigate to product offers screen for price comparison
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductOffersScreen(
                                product: result,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _apiResponse,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 