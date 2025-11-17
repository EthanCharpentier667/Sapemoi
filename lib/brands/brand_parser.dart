import 'dart:convert';
import 'package:http/http.dart' as http;
import 'scrapers/zara.dart';

class BrandInfo {
  final String? brand;
  final String? productCode;
  final String? productName;
  final String? category;
  final String? color;
  final String? size;
  final String? price;
  final String? imageUrl;
  final String? description;
  final Map<String, dynamic>? additionalData;
  final bool needsAIAnalysis; // True if we should send to AI for color/type analysis

  BrandInfo({
    this.brand,
    this.productCode,
    this.productName,
    this.category,
    this.color,
    this.size,
    this.price,
    this.imageUrl,
    this.description,
    this.additionalData,
    this.needsAIAnalysis = false,
  });

  bool get hasEnoughData => brand != null || productName != null;

  @override
  String toString() {
    return 'Brand: $brand, Product: $productCode, Name: $productName, Category: $category';
  }

  factory BrandInfo.fromJson(Map<String, dynamic> json) {
    return BrandInfo(
      brand: json['brand'],
      productCode: json['barcode'] ?? json['ean'] ?? json['gtin'],
      productName: json['title'] ?? json['product_name'] ?? json['description'],
      category: json['category'],
      imageUrl: json['image'] ?? json['images']?[0],
      description: json['description'],
      price: json['price']?.toString(),
      additionalData: json,
    );
  }
}

// GS1 Company Prefix to Brand mapping (most common fashion brands)
class GS1Prefixes {
  static final Map<String, String> countryPrefixes = {
    '00': 'USA/Canada',
    '30-37': 'France',
    '40-44': 'Germany',
    '45-49': 'Japan',
    '50': 'UK',
    '54': 'Belgium/Luxembourg',
    '57': 'Denmark',
    '64': 'Finland',
    '69': 'China',
    '70': 'Norway',
    '73': 'Sweden',
    '76': 'Switzerland',
    '80-83': 'Italy',
    '84': 'Spain',
    '87': 'Netherlands',
    '90-91': 'Austria',
  };
  
  // Common fashion brand GS1 prefixes (examples - would need full database)
  static final Map<String, String> brandPrefixes = {
    // These are examples - real GS1 company prefixes are much longer
    '84210': 'Zara (Inditex)',
    '84211': 'Pull&Bear (Inditex)',
    '84212': 'Bershka (Inditex)',
    '73': 'H&M Group',
  };
  
  static String? getBrandFromEAN(String ean) {
    if (ean.length < 7) return null;
    
    // Try 5-digit company prefix
    final prefix5 = ean.substring(0, 5);
    if (brandPrefixes.containsKey(prefix5)) {
      print('[GS1] Brand identified: ${brandPrefixes[prefix5]}');
      return brandPrefixes[prefix5];
    }
    
    // Try 2-digit country code (less reliable for brand)
    final prefix2 = ean.substring(0, 2);
    if (countryPrefixes.containsKey(prefix2)) {
      print('[GS1] Country: ${countryPrefixes[prefix2]}');
    }
    
    return null;
  }
}

class BarcodeScanner {
  static Future<BrandInfo?> scan(String code) async {
    print('========== BARCODE SCANNER ==========');
    print('Input: $code');
    
    // Normalize code
    final normalizedCode = code.trim();
    final lowerCode = normalizedCode.toLowerCase();
    
    print('Type: ${_getCodeType(normalizedCode)}');
    
    // Detect code type
    if (RegExp(r'^\d{8,14}$').hasMatch(normalizedCode)) {
      // EAN/GTIN barcode
      print('Detected: EAN/GTIN barcode');
      print('Length: ${normalizedCode.length} digits');
      
      // Try GS1 prefix lookup
      final brand = GS1Prefixes.getBrandFromEAN(normalizedCode);
      
      // Always try API lookup for complete product info
      print('🔍 Looking up product in databases...');
      final apiResult = await _lookupEAN(normalizedCode);
      
      if (apiResult != null && apiResult.hasEnoughData) {
        print('✅ Product found via API');
        print('Product: ${apiResult.productName}');
        print('⏭️  Will send to AI for brand/color/type analysis');
        print('====================================');

        return BrandInfo(
          brand: null,
          productCode: apiResult.productCode,
          productName: apiResult.productName,
          category: apiResult.category,
          imageUrl: apiResult.imageUrl,
          description: apiResult.description,
          additionalData: apiResult.additionalData,
          needsAIAnalysis: true,
        );
      } else if (brand != null) {
        print('⚠️ API lookup failed, using GS1 brand only');
        print('⏭️  Will send to AI for complete analysis');
        print('====================================');
        return BrandInfo(
          brand: brand,
          productCode: normalizedCode,
          productName: 'Product',
          needsAIAnalysis: true,
        );
      } else {
        print('❌ Product not found in any database');
        print('⏭️  Will send to AI for analysis');
        print('====================================');
        return BrandInfo(
          productCode: normalizedCode,
          productName: 'Unknown Product',
          needsAIAnalysis: true,
        );
      }
    } else if (lowerCode.startsWith('http://') || lowerCode.startsWith('https://')) {
      // URL - try to extract brand from domain
      print('Detected: URL/QR Code');
      final uri = Uri.tryParse(normalizedCode);
      if (uri != null) {
        final brand = _extractBrandFromDomain(uri.host);
        print('Domain: ${uri.host}');
        if (brand != null) {
          print('Brand detected: $brand');
        }
        
        // Try to extract product code from URL
        final productCode = _extractProductCode(uri);
        if (productCode != null) {
          print('Product code extracted: $productCode');
        }
        
        // If we have both brand and product code, return immediately
        if (brand != null && productCode != null) {
          print('✅ Brand and product code extracted from URL');
          
          // Try to scrape product name for specific brands
          String? scrapedProductName;
          if (brand.toLowerCase().contains('zara')) {
            print('🕷️ Attempting to scrape Zara product name...');
            scrapedProductName = await ZaraScraper.getProductName(productCode);
          }
          
          final finalProductName = scrapedProductName ?? '$brand $productCode';
          
          print('⏭️  Will send to AI for complete analysis');
          print('====================================');
          return BrandInfo(
            brand: brand,
            productCode: productCode,
            productName: finalProductName,
            needsAIAnalysis: true,
          );
        }
        
        // If we're missing info, try AI API
        if (brand == null || productCode == null) {
          print('🤖 URL analysis needed, calling AI API...');
          final aiResult = await _analyzeURLWithAI(normalizedCode);
          if (aiResult != null && aiResult.hasEnoughData) {
            print('✅ AI analysis successful');
            print('====================================');
            return aiResult;
          }
          
          // AI failed, return what we have
          if (brand != null || productCode != null) {
            print('⚠️ AI failed, using extracted data');
            print('====================================');
            return BrandInfo(
              brand: brand,
              productCode: productCode,
              productName: productCode != null && brand != null ? '$brand $productCode' : null,
            );
          }
        }
        
        print('====================================');
        return BrandInfo(
          brand: brand,
          productCode: productCode,
          productName: productCode != null ? '$brand $productCode' : null,
        );
      }
    }
    
    print('❌ Unsupported code format');
    print('====================================');
    return null;
  }
  
  static String _getCodeType(String code) {
    final lower = code.toLowerCase();
    if (code.length == 8 && RegExp(r'^\d+$').hasMatch(code)) return 'EAN-8';
    if (code.length == 12 && RegExp(r'^\d+$').hasMatch(code)) return 'UPC-A';
    if (code.length == 13 && RegExp(r'^\d+$').hasMatch(code)) return 'EAN-13';
    if (code.length == 14 && RegExp(r'^\d+$').hasMatch(code)) return 'GTIN-14';
    if (lower.startsWith('http://') || lower.startsWith('https://')) return 'QR/URL';
    return 'Unknown';
  }
  
  static String? _extractBrandFromDomain(String host) {
    final domain = host.toLowerCase();
    
    // Common fashion domains
    if (domain.contains('zara.com')) return 'Zara';
    if (domain.contains('hm.com')) return 'H&M';
    if (domain.contains('uniqlo.com')) return 'Uniqlo';
    if (domain.contains('nike.com')) return 'Nike';
    if (domain.contains('adidas.com')) return 'Adidas';
    if (domain.contains('pullandbear.com')) return 'Pull&Bear';
    if (domain.contains('bershka.com')) return 'Bershka';
    if (domain.contains('stradivarius.com')) return 'Stradivarius';
    if (domain.contains('mango.com')) return 'Mango';
    if (domain.contains('gap.com')) return 'Gap';
    if (domain.contains('lacoste.com')) return 'Lacoste';
    if (domain.contains('puma.com')) return 'Puma';
    if (domain.contains('lululemon.com')) return 'Lululemon';
    if (domain.contains('levi.com') || domain.contains('levis.com')) return "Levi's";
    if (domain.contains('reebok.com')) return 'Reebok';
    if (domain.contains('newbalance.com')) return 'New Balance';
    if (domain.contains('vans.com')) return 'Vans';
    if (domain.contains('converse.com')) return 'Converse';
    if (domain.contains('celio.com')) return 'Celio';
    if (domain.contains('jules.com')) return 'Jules';
    if (domain.contains('reserved.com')) return 'Reserved';
    if (domain.contains('massimodutti.com')) return 'Massimo Dutti';
    
    return null;
  }
  
  static String? _extractProductCode(Uri uri) {
    // Nike QR codes: qr.nike.com/{code}
    if (uri.host.toLowerCase().contains('qr.nike.com') && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    
    // Zara style: /product/{code}
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'product') {
      return uri.pathSegments[1];
    }
    
    // Try to extract long numeric code from URL path (8+ digits)
    final numericMatch = RegExp(r'\d{8,}').firstMatch(uri.path);
    if (numericMatch != null) {
      return numericMatch.group(0);
    }
    
    // Try to extract product code after -p or /p/
    final productMatch = RegExp(r'[-/]p[/-]?(\w+)').firstMatch(uri.path);
    if (productMatch != null) {
      return productMatch.group(1);
    }
    
    // Try to extract any alphanumeric code from path (fallback)
    if (uri.pathSegments.isNotEmpty) {
      // Get last segment that looks like a product code
      for (var segment in uri.pathSegments.reversed) {
        if (segment.length >= 6 && RegExp(r'^[A-Z0-9]+$', caseSensitive: false).hasMatch(segment)) {
          return segment;
        }
      }
    }
    
    return null;
  }
  
  static Future<BrandInfo?> _lookupEAN(String ean) async {
    // Try multiple APIs in sequence
    
    // 1. Try UPCItemDB (free tier)
    final upcResult = await _lookupUPCItemDB(ean);
    if (upcResult != null && upcResult.hasEnoughData) {
      return upcResult;
    }
    
    // 2. Try Open Food Facts (good for clothing too)
    final offResult = await _lookupOpenFoodFacts(ean);
    if (offResult != null && offResult.hasEnoughData) {
      return offResult;
    }
    
    // 3. Try Barcode Lookup API
    final barcodeResult = await _lookupBarcodeLookup(ean);
    if (barcodeResult != null && barcodeResult.hasEnoughData) {
      return barcodeResult;
    }
    
    return null;
  }
  
  static Future<BrandInfo?> _lookupUPCItemDB(String ean) async {
    try {
      print('[API] UPCItemDB lookup...');
      final url = Uri.parse('https://api.upcitemdb.com/prod/trial/lookup?upc=$ean');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['items'] != null && data['items'].isNotEmpty) {
          final item = data['items'][0];
          print('[API] ✅ UPCItemDB found: ${item['title']}');
          return BrandInfo(
            brand: item['brand'],
            productCode: ean,
            productName: item['title'],
            category: item['category'],
            imageUrl: item['images']?[0],
            description: item['description'],
            additionalData: item,
          );
        }
      }
      print('[API] ⚠️ UPCItemDB: No results');
      return null;
    } catch (e) {
      print('[API] ❌ UPCItemDB error: $e');
      return null;
    }
  }
  
  static Future<BrandInfo?> _lookupOpenFoodFacts(String ean) async {
    try {
      print('[API] Open Food Facts lookup...');
      final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$ean.json');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'];
          print('[API] ✅ Open Food Facts found: ${product['product_name']}');
          return BrandInfo(
            brand: product['brands'],
            productCode: ean,
            productName: product['product_name'],
            category: product['categories'],
            imageUrl: product['image_url'],
            additionalData: product,
          );
        }
      }
      print('[API] ⚠️ Open Food Facts: No results');
      return null;
    } catch (e) {
      print('[API] ❌ Open Food Facts error: $e');
      return null;
    }
  }
  
  static Future<BrandInfo?> _lookupBarcodeLookup(String ean) async {
    try {
      // API key can be set in environment or left empty to skip this API
      const apiKey = String.fromEnvironment('BARCODE_LOOKUP_API_KEY', defaultValue: '');
      if (apiKey.isEmpty) {
        print('[API] ⚠️ Barcode Lookup: No API key configured');
        return null;
      }
      
      print('[API] Barcode Lookup API...');
      final url = Uri.parse('https://api.barcodelookup.com/v3/products?barcode=$ean&key=$apiKey');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['products'] != null && data['products'].isNotEmpty) {
          final product = data['products'][0];
          print('[API] ✅ Barcode Lookup found: ${product['title']}');
          return BrandInfo(
            brand: product['brand'],
            productCode: ean,
            productName: product['title'],
            category: product['category'],
            imageUrl: product['images']?[0],
            description: product['description'],
            additionalData: product,
          );
        }
      }
      print('[API] ⚠️ Barcode Lookup: No results');
      return null;
    } catch (e) {
      print('[API] ❌ Barcode Lookup error: $e');
      return null;
    }
  }
  
  static Future<BrandInfo?> _analyzeURLWithAI(String url) async {
    try {
      print('[AI] Analyzing URL with AI...');
      final apiUrl = Uri.parse('https://sapemoi-api.onrender.com/analyze_url');
      
      final response = await http.post(
        apiUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'url': url}),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('[AI] ✅ AI analysis complete');
        return BrandInfo(
          brand: data['brand'],
          productCode: data['product_code'],
          productName: data['product_name'],
          category: data['category'],
          imageUrl: data['image_url'],
          description: data['description'],
          additionalData: data,
        );
      }
      
      print('[AI] ⚠️ AI analysis failed: ${response.statusCode}');
      return null;
    } catch (e) {
      print('[AI] ❌ URL analysis error: $e');
      return null;
    }
  }
}

