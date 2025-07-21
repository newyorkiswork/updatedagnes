import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class SearchApiService {
  // SerpAPI configuration
  static const String _serpApiKey = '8efe73fc2c0004ba75fc593c3955a4d4f60c87d5904a13fdba1550800adeed64';
  static const String _serpBaseUrl = 'https://serpapi.com/search';
  
  // Legacy SearchAPI configuration (keeping for fallback)
  static const String _legacyBaseUrl = 'https://www.searchapi.io/api/v1/search';
  static const String _legacyApiKey = 'DHG5nvk4jtSTBESjwSiYfAYF';

  static Future<Map<String, dynamic>> searchGoogleShopping({
    required String query,
    String country = 'us',
    String language = 'en',
    String location = 'California, United States',
  }) async {
    try {
      final url = Uri.parse(_serpBaseUrl).replace(queryParameters: {
        'api_key': _serpApiKey,
        'engine': 'google_shopping',
        'q': query,
        'gl': country,
        'hl': language,
        'location': location,
      });

      print('🔍 Making SerpAPI Google Shopping request to: $url');

      final response = await http.get(url);

      print('🔍 SerpAPI Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
          'rawResponse': response.body,
        };
      } else {
        return {
          'success': false,
          'error': 'SerpAPI Error: ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      print('❌ Network error: $e');
      return {
        'success': false,
        'error': 'Network Error: $e',
      };
    }
  }

  static List<Map<String, dynamic>> parseShoppingResults(Map<String, dynamic> apiData) {
    final List<Map<String, dynamic>> results = [];
    
    try {
      print('🔍 Parsing SerpAPI results...');
      print('🔍 API data keys: ${apiData.keys.toList()}');
      
      // Parse SerpAPI Google Shopping results
      final shoppingResults = apiData['shopping_results'];
      if (shoppingResults != null && shoppingResults is List) {
        print('🔍 Found ${shoppingResults.length} shopping results');
        
        for (var result in shoppingResults) {
          if (result is Map<String, dynamic>) {
            // Extract product ID from the link or other fields
            String? productId = _extractProductIdFromLink(result['link']?.toString() ?? '');
            
            results.add({
              'type': 'result',
              'title': result['title']?.toString() ?? 'No title',
              'price': result['price']?.toString() ?? 'No price',
              'seller': result['seller']?.toString() ?? 'No seller',
              'rating': result['rating']?.toString() ?? 'No rating',
              'reviews': result['reviews']?.toString() ?? 'No reviews',
              'offers': result['offers']?.toString() ?? 'No offers',
              'thumbnail': result['thumbnail']?.toString() ?? '',
              'link': result['link']?.toString() ?? '',
              'product_id': productId,
              'product_id_raw': result['product_id']?.toString() ?? result['productId']?.toString(),
              'serpapi_product_api': result['serpapi_product_api']?.toString(),
            });
          }
        }
      } else {
        print('🔍 No shopping_results found or not a list: $shoppingResults');
      }
      
      // Also parse any ads if available
      final shoppingAds = apiData['shopping_ads'];
      if (shoppingAds != null && shoppingAds is List) {
        print('🔍 Found ${shoppingAds.length} shopping ads');
        
        for (var ad in shoppingAds) {
          if (ad is Map<String, dynamic>) {
            String? productId = _extractProductIdFromLink(ad['link']?.toString() ?? '');
            
            results.add({
              'type': 'ad',
              'title': ad['title']?.toString() ?? 'No title',
              'price': ad['price']?.toString() ?? 'No price',
              'seller': ad['seller']?.toString() ?? 'No seller',
              'rating': ad['rating']?.toString() ?? 'No rating',
              'reviews': ad['reviews']?.toString() ?? 'No reviews',
              'thumbnail': ad['thumbnail']?.toString() ?? '',
              'link': ad['link']?.toString() ?? '',
              'product_id': productId,
              'product_id_raw': ad['product_id']?.toString() ?? ad['productId']?.toString(),
              'serpapi_product_api': ad['serpapi_product_api']?.toString(),
            });
          }
        }
      } else {
        print('🔍 No shopping_ads found or not a list: $shoppingAds');
      }
      
      print('🔍 Successfully parsed ${results.length} total results');
    } catch (e) {
      print('❌ Error parsing SerpAPI results: $e');
      print('❌ Error details: ${e.toString()}');
    }
    
    return results;
  }

  static String? _extractProductIdFromLink(String link) {
    try {
      if (link.isEmpty) return null;
      
      // Try to extract product ID from Google Shopping URLs
      final uri = Uri.tryParse(link);
      if (uri != null) {
        // Check for product_id parameter
        final productIdParam = uri.queryParameters['product_id'];
        if (productIdParam != null && productIdParam.isNotEmpty) {
          print('🔍 Extracted product ID from parameter: $productIdParam');
          return productIdParam;
        }
        
        // Check for product ID in path segments
        final pathSegments = uri.pathSegments;
        for (int i = 0; i < pathSegments.length; i++) {
          if (pathSegments[i] == 'product' && i + 1 < pathSegments.length) {
            final potentialId = pathSegments[i + 1];
            if (RegExp(r'^\d+$').hasMatch(potentialId)) {
              print('🔍 Extracted product ID from path: $potentialId');
              return potentialId;
            }
          }
        }
        
        // Try to extract from shopping URLs
        if (link.contains('/shopping/product/')) {
          final match = RegExp(r'/shopping/product/(\d+)').firstMatch(link);
          if (match != null) {
            final productId = match.group(1);
            print('🔍 Extracted product ID from shopping URL: $productId');
            return productId;
          }
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Error extracting product ID from link: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> searchByImage(File imageFile) async {
    try {
      print('🔍 Starting OCR text extraction from image...');
      
      // First, try OCR text extraction
      final extractedText = await extractTextFromImage(imageFile);
      print('🔍 OCR extracted text: "$extractedText"');
      
      if (extractedText.isNotEmpty) {
        // Extract product query from OCR text
        final productQuery = extractProductQueryFromText(extractedText);
        print('🔍 Extracted product query from OCR: "$productQuery"');
        
        if (productQuery.isNotEmpty) {
          // Search Google Shopping with the extracted product query
          final shoppingResult = await searchGoogleShopping(query: productQuery);
          
          if (shoppingResult['success']) {
            return {
              'success': true,
              'data': {
                'ocr_extracted_text': extractedText,
                'extracted_query': productQuery,
                'shopping_results': shoppingResult['data']['shopping_results'] ?? [],
                'shopping_ads': shoppingResult['data']['shopping_ads'] ?? [],
              },
              'message': 'Found results for: $productQuery',
            };
          }
        }
      }
      
      // If OCR didn't work, try SerpAPI Google Reverse Image search
      print('🔍 OCR didn\'t work, trying SerpAPI Google Reverse Image search...');
      
      // Convert image to base64 for SerpAPI
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      
      // Make Google Reverse Image search request
      final reverseImageResult = await _performReverseImageSearch(base64Image);
      
      if (reverseImageResult['success']) {
        final data = reverseImageResult['data'];
        
        // Extract product information from reverse image results
        final productInfo = _extractProductFromReverseImage(data);
        
        if (productInfo.isNotEmpty) {
          print('🔍 Extracted product info from reverse image: $productInfo');
          
          // Search Google Shopping with the extracted product info
          final shoppingResult = await searchGoogleShopping(query: productInfo);
          
          if (shoppingResult['success']) {
            return {
              'success': true,
              'data': {
                'reverse_image_data': data,
                'extracted_product': productInfo,
                'shopping_results': shoppingResult['data']['shopping_results'] ?? [],
                'shopping_ads': shoppingResult['data']['shopping_ads'] ?? [],
              },
              'message': 'Found product: $productInfo',
            };
          }
        }
        
        // If no specific product found, try to extract search query from image results
        final searchQuery = _extractSearchQueryFromImageResults(data);
        if (searchQuery != null) {
          print('🔍 Extracted search query: $searchQuery');
          
          final shoppingResult = await searchGoogleShopping(query: searchQuery);
          if (shoppingResult['success']) {
            return {
              'success': true,
              'data': {
                'reverse_image_data': data,
                'extracted_query': searchQuery,
                'shopping_results': shoppingResult['data']['shopping_results'] ?? [],
                'shopping_ads': shoppingResult['data']['shopping_ads'] ?? [],
              },
              'message': 'Found results for: $searchQuery',
            };
          }
        }
      }
      
      // If both OCR and reverse image search didn't work, return OCR text for manual search
      if (extractedText.isNotEmpty) {
        final productQuery = extractProductQueryFromText(extractedText);
        return {
          'success': true,
          'data': {
            'ocr_extracted_text': extractedText,
            'extracted_query': productQuery,
            'manual_search_needed': true,
            'shopping_results': [],
            'shopping_ads': [],
          },
          'message': 'Text extracted: $productQuery. Please search manually.',
        };
      }
      
      // Final fallback
      print('🔍 All methods failed, using generic fallback...');
      return await _fallbackImageSearch();
      
    } catch (e) {
      print('❌ Image search error: $e');
      return await _fallbackImageSearch();
    }
  }

  static Future<Map<String, dynamic>> _smartFallbackForOneADay() async {
    try {
      print('🔍 Trying smart fallback for ONE A DAY products...');
      
      // Try specific ONE A DAY searches
      final oneADaySearches = [
        "ONE A DAY MEN'S multivitamin",
        "ONE A DAY MEN complete",
        "Bayer ONE A DAY MEN",
        "ONE A DAY multivitamin",
        "ONE A DAY complete",
      ];
      
      for (String searchQuery in oneADaySearches) {
        print('🔍 Trying search: $searchQuery');
        
        final result = await searchGoogleShopping(query: searchQuery);
        if (result['success']) {
          final data = result['data'];
          final parsedResults = parseShoppingResults(data);
          
          if (parsedResults.isNotEmpty) {
            print('🔍 Found ${parsedResults.length} results for: $searchQuery');
            return {
              'success': true,
              'data': {
                'fallback_search': true,
                'smart_fallback': true,
                'used_query': searchQuery,
                'alternative_queries': oneADaySearches,
                'shopping_results': data['shopping_results'] ?? [],
                'shopping_ads': data['shopping_ads'] ?? [],
              },
              'message': 'Found ONE A DAY results using: $searchQuery',
            };
          }
        }
      }
      
      // If ONE A DAY searches didn't work, try generic fallback
      return await _fallbackImageSearch();
      
    } catch (e) {
      print('❌ Smart fallback error: $e');
      return await _fallbackImageSearch();
    }
  }

  static Future<Map<String, dynamic>> _performReverseImageSearch(String base64Image) async {
    try {
      final url = Uri.parse(_serpBaseUrl);
      
      print('🔍 Making SerpAPI Google Reverse Image request...');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'api_key': _serpApiKey,
          'engine': 'google_reverse_image',
          'image': base64Image,
          'gl': 'us',
          'hl': 'en',
        }),
      );

      print('🔍 SerpAPI Reverse Image Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔍 SerpAPI Reverse Image Response Data: ${json.encode(data)}');
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'SerpAPI Reverse Image Error: ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      print('❌ SerpAPI Reverse Image error: $e');
      return {
        'success': false,
        'error': 'SerpAPI Reverse Image Error: $e',
      };
    }
  }

  static String _extractProductFromReverseImage(Map<String, dynamic> data) {
    try {
      print('🔍 Analyzing reverse image data for product extraction...');
      print('🔍 Available keys in data: ${data.keys.toList()}');
      
      // Check for shopping results first
      final shoppingResults = data['shopping_results'] as List<dynamic>? ?? [];
      print('🔍 Found ${shoppingResults.length} shopping results');
      if (shoppingResults.isNotEmpty) {
        final firstResult = shoppingResults.first;
        print('🔍 First shopping result: $firstResult');
        final title = firstResult['title'] as String? ?? '';
        if (title.isNotEmpty) {
          print('🔍 Extracted from shopping results: $title');
          return title;
        }
      }
      
      // Check for image results
      final imageResults = data['image_results'] as List<dynamic>? ?? [];
      print('🔍 Found ${imageResults.length} image results');
      if (imageResults.isNotEmpty) {
        final firstResult = imageResults.first;
        print('🔍 First image result: $firstResult');
        final title = firstResult['title'] as String? ?? '';
        if (title.isNotEmpty) {
          print('🔍 Extracted from image results: $title');
          return title;
        }
      }
      
      // Check for organic results
      final organicResults = data['organic_results'] as List<dynamic>? ?? [];
      print('🔍 Found ${organicResults.length} organic results');
      if (organicResults.isNotEmpty) {
        final firstResult = organicResults.first;
        print('🔍 First organic result: $firstResult');
        final title = firstResult['title'] as String? ?? '';
        if (title.isNotEmpty) {
          print('🔍 Extracted from organic results: $title');
          return title;
        }
      }
      
      // Check for search information
      final searchInfo = data['search_information'] as Map<String, dynamic>?;
      if (searchInfo != null) {
        print('🔍 Search information: $searchInfo');
        final queryDisplayed = searchInfo['query_displayed'] as String?;
        if (queryDisplayed != null && queryDisplayed.isNotEmpty) {
          print('🔍 Extracted from search info: $queryDisplayed');
          return queryDisplayed;
        }
      }
      
      print('🔍 No product information could be extracted from reverse image data');
      return '';
    } catch (e) {
      print('❌ Error extracting product from reverse image: $e');
      return '';
    }
  }

  static String? _extractSearchQueryFromImageResults(Map<String, dynamic> data) {
    try {
      // Check for search information
      final searchInfo = data['search_information'] as Map<String, dynamic>?;
      if (searchInfo != null) {
        final queryDisplayed = searchInfo['query_displayed'] as String?;
        if (queryDisplayed != null && queryDisplayed.isNotEmpty) {
          print('🔍 Extracted query from search info: $queryDisplayed');
          return queryDisplayed;
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Error extracting search query: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> getProductOffers({
    required String productId,
    String gl = 'us',
    String hl = 'en',
  }) async {
    try {
      print('🔍 Getting product offers for ID: $productId');
      
      final url = Uri.parse(_serpBaseUrl);
      
      final response = await http.get(
        url.replace(queryParameters: {
          'api_key': _serpApiKey,
          'engine': 'google_product',
          'product_id': productId,
          'gl': gl,
          'hl': hl,
        }),
      );

      print('🔍 Product Offers Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get product offers: ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('❌ Error getting product offers: $e');
      return {
        'success': false,
        'error': 'Error getting product offers: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getLiveProductOffers({
    required String serpapiProductApiUrl,
    String gl = 'us',
    String hl = 'en',
  }) async {
    try {
      print('🔍 Getting live product offers from: $serpapiProductApiUrl');
      
      // Parse the URL to get the product_id parameter
      final uri = Uri.parse(serpapiProductApiUrl);
      final productId = uri.queryParameters['product_id'];
      
      if (productId == null || productId.isEmpty) {
        return {
          'success': false,
          'error': 'No product ID found in SerpAPI URL',
        };
      }
      
      print('🔍 Extracted product ID: $productId');
      
      // Make the request to get live product offers
      final url = Uri.parse(_serpBaseUrl);
      
      final response = await http.get(
        url.replace(queryParameters: {
          'api_key': _serpApiKey,
          'engine': 'google_product',
          'product_id': productId,
          'gl': gl,
          'hl': hl,
        }),
      );

      print('🔍 Live Product Offers Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔍 Live Product Offers Data: ${json.encode(data)}');
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get live product offers: ${response.statusCode}',
          'statusCode': response.statusCode,
          'response': response.body,
        };
      }
    } catch (e) {
      print('❌ Error getting live product offers: $e');
      return {
        'success': false,
        'error': 'Error getting live product offers: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> _fallbackImageSearch() async {
    try {
      // Generic vitamin search as fallback
      final result = await searchGoogleShopping(query: 'multivitamin supplement');
      
      return {
        'success': true,
        'data': {
          'fallback_search': true,
          'suggested_searches': [
            'multivitamin supplements',
            'vitamins and supplements',
            'health products',
            'personal care products',
            'household items',
            'electronics',
            'books',
            'clothing',
            'food and beverages'
          ],
          'current_search': 'multivitamin supplement',
          'shopping_results': result['success'] ? result['data']['shopping_results'] : [],
          'shopping_ads': result['success'] ? result['data']['shopping_ads'] : [],
        },
        'message': 'Image captured! Here are some vitamin and supplement results. Tap to refine your search.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Fallback search also failed: $e',
      };
    }
  }

  // OCR methods using Google ML Kit
  static Future<String> extractTextFromImage(File imageFile) async {
    try {
      print('🔍 Starting OCR text extraction...');
      
      // Create input image
      final inputImage = InputImage.fromFile(imageFile);
      
      // Create text recognizer
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      
      // Process the image
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      // Extract all text blocks
      final List<String> textBlocks = [];
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          for (TextElement element in line.elements) {
            textBlocks.add(element.text);
          }
        }
      }
      
      final extractedText = textBlocks.join(' ');
      print('🔍 OCR extracted text: "$extractedText"');
      
      // Close the recognizer
      textRecognizer.close();
      
      return extractedText;
    } catch (e) {
      print('❌ OCR error: $e');
      return '';
    }
  }

  static String extractProductQueryFromText(String text) {
    try {
      print('🔍 Extracting product query from text: "$text"');
      
      // Convert to lowercase for better matching
      final lowerText = text.toLowerCase();
      
      // Look for common product keywords
      final productKeywords = [
        'castor oil',
        'vitamin',
        'multivitamin',
        'supplement',
        'oil',
        'cream',
        'lotion',
        'shampoo',
        'soap',
        'medicine',
        'pill',
        'tablet',
        'capsule',
        'gummy',
        'powder',
        'liquid',
        'organic',
        'natural',
        'pure',
        'extra virgin',
        'cold pressed',
      ];
      
      // Find the most relevant product keyword
      String bestMatch = '';
      for (String keyword in productKeywords) {
        if (lowerText.contains(keyword)) {
          if (keyword.length > bestMatch.length) {
            bestMatch = keyword;
          }
        }
      }
      
      // If we found a product keyword, extract the full product name
      if (bestMatch.isNotEmpty) {
        // Look for text around the keyword
        final keywordIndex = lowerText.indexOf(bestMatch);
        final startIndex = (keywordIndex - 20).clamp(0, text.length);
        final endIndex = (keywordIndex + bestMatch.length + 20).clamp(0, text.length);
        
        String productName = text.substring(startIndex, endIndex).trim();
        
        // Clean up the product name
        productName = productName.replaceAll(RegExp(r'[^\w\s\-%]'), ' ').trim();
        productName = productName.replaceAll(RegExp(r'\s+'), ' ');
        
        print('🔍 Extracted product name: "$productName"');
        return productName;
      }
      
      // If no specific product keyword found, return the first few words
      final words = text.split(' ').where((word) => word.length > 2).take(5).toList();
      final fallbackQuery = words.join(' ');
      
      print('🔍 Using fallback query: "$fallbackQuery"');
      return fallbackQuery;
      
    } catch (e) {
      print('❌ Error extracting product query: $e');
      return text.substring(0, text.length.clamp(0, 50)).trim();
    }
  }
} 