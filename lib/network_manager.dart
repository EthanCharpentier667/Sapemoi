import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  final String endpoint = 'https://sapemoi-api.onrender.com/analyze';
  final String totalEndpoint = 'https://sapemoi-api.onrender.com/total';
  final String analyzeWithInfoEndpoint = 'https://sapemoi-api.onrender.com/analyze_with_info';
  final String analyzeBarcodeProductEndpoint = 'https://sapemoi-api.onrender.com/analyze_barcode_product';

  Future<Map<String, dynamic>> estimateWardrobeValue(
    List<Map<String, dynamic>> items, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    try {
      print('🔄 Estimating wardrobe value for ${items.length} items');

      final payload = {'items': items.map((item) => {
        'brand': item['brand'],
        'product': item['product'],
        'type': item['type'],
        'specificType': item['specificType'],
      }).toList()};
      final body = json.encode(payload);

      final response = await http
          .post(
            Uri.parse(totalEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);

      print('📥 Total response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      
      if (jsonData.containsKey('error')) {
        throw Exception('API Error: ${jsonData['error']}');
      }

      final total = jsonData['total'] as num?;
      final breakdown = jsonData['breakdown'] as List<dynamic>?;
      
      if (total == null) {
        throw Exception('Missing total in response');
      }

      print('✅ Wardrobe value estimated: \$${total}');
      return {
        'total': total.toDouble(),
        'breakdown': breakdown ?? [],
      };
    } catch (e) {
      print('❌ Network error: $e');
      rethrow;
    }
  }

  Future<AnalysisResult> analyzeImage(
    String base64Image, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    try {
      print('🔄 Preparing request to: $endpoint');

      final payload = {'base64': base64Image};
      final body = json.encode(payload);

      print('📤 Request body size: ${body.length} bytes');

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);

      print('📥 Response status: ${response.statusCode}');
      print('📥 Raw response (${response.body.length} bytes):');
      print(response.body);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      print('✅ JSON parsed successfully');
      print('JSON keys: ${jsonData.keys.join(", ")}');

      if (jsonData.containsKey('error')) {
        final isClothing = jsonData['isClothing'] as bool? ?? true;
        if (!isClothing) {
          throw Exception('Not a clothing item. Please upload an image of clothing, footwear, or fashion accessories.');
        }
        throw Exception('API Error: ${jsonData['error']}');
      }

      final choices = jsonData['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('Missing "choices" in response');
      }

      print('✅ Found ${choices.length} choice(s)');

      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;

      if (content == null) {
        throw Exception('Missing message or content in choices');
      }

      print('✅ Content extracted: $content');

      final type = _parseType(content);
      final specificType = _parseSpecificType(content);
      final colors = _parseColors(content);
      final brand = _parseBrand(content);
      final product = _parseProduct(content);

      print('✅ Parsed - type: $type, specificType: $specificType, colors: ${colors.length}, brand: $brand, product: $product');

      return AnalysisResult(
        type: type,
        specificType: specificType,
        colors: colors,
        brand: brand,
        product: product,
      );
    } catch (e) {
      print('❌ Network error: $e');
      rethrow;
    }
  }

  /// Analyze image with pre-existing barcode info (no Google Lens needed)
  Future<AnalysisResult> analyzeWithBarcodeInfo(
    String base64Image,
    String productCode,
    String productName, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    try {
      print('🤖 Analyzing image with barcode info...');
      print('   Product: $productName ($productCode)');

      final payload = {
        'base64': base64Image,
        'product_code': productCode,
        'product_name': productName,
      };
      final body = json.encode(payload);

      final response = await http
          .post(
            Uri.parse(analyzeWithInfoEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      print('✅ AI analysis complete');

      if (jsonData.containsKey('error')) {
        throw Exception('API Error: ${jsonData['error']}');
      }

      final choices = jsonData['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('Missing "choices" in response');
      }

      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;

      if (content == null) {
        throw Exception('Missing message or content in choices');
      }

      final type = _parseType(content);
      final specificType = _parseSpecificType(content);
      final colors = _parseColors(content);
      final brand = _parseBrand(content);
      final product = _parseProduct(content);

      print('✅ AI Parsed - type: $type, specificType: $specificType, colors: ${colors.length}');

      return AnalysisResult(
        type: type,
        specificType: specificType,
        colors: colors,
        brand: brand,
        product: product,
      );
    } catch (e) {
      print('❌ AI analysis error: $e');
      rethrow;
    }
  }

  /// Analyze barcode product automatically with Google Images search
  /// No user photo needed - API finds product image and analyzes it!
  Future<AnalysisResult> analyzeBarcodeProduct(
    String productCode,
    String productName, {
    String? brand,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    try {
      print('🔍 Auto-analyzing product: $productName');
      if (brand != null) print('   Brand: $brand');

      final payload = {
        'product_code': productCode,
        'product_name': productName,
        if (brand != null) 'brand': brand,
      };
      final body = json.encode(payload);

      final response = await http
          .post(
            Uri.parse(analyzeBarcodeProductEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      print('✅ Auto-analysis complete');

      if (jsonData.containsKey('error')) {
        throw Exception('API Error: ${jsonData['error']}');
      }

      final imageUrl = jsonData['image_url'] as String?;
      String? imageBase64;
      
      if (imageUrl != null) {
        print('🖼️  Found image: $imageUrl');
        try {
          final imageResponse = await http.get(Uri.parse(imageUrl)).timeout(
            const Duration(seconds: 30),
          );
          if (imageResponse.statusCode == 200) {
            imageBase64 = base64Encode(imageResponse.bodyBytes);
            print('✅ Image downloaded and converted to base64 (${imageBase64.length} chars)');
          } else {
            print('⚠️  Failed to download image: ${imageResponse.statusCode}');
          }
        } catch (e) {
          print('⚠️  Image download error: $e');
        }
      }

      final choices = jsonData['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('Missing "choices" in response');
      }

      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;

      if (content == null) {
        throw Exception('Missing message or content in choices');
      }

      final type = _parseType(content);
      final specificType = _parseSpecificType(content);
      final colors = _parseColors(content);
      final parsedBrand = _parseBrand(content);
      final product = _parseProduct(content);

      print('✅ Parsed - type: $type, specificType: $specificType, colors: ${colors.length}');

      return AnalysisResult(
        type: type,
        specificType: specificType,
        colors: colors,
        brand: parsedBrand,
        product: product,
        imageUrl: imageUrl,
        imageBase64: imageBase64,
      );
    } catch (e) {
      print('❌ Auto-analysis error: $e');
      rethrow;
    }
  }

  String _parseType(String content) {
    return _parseField(content, 'Type') ?? 'unknown';
  }

  String _parseSpecificType(String content) {
    return _parseField(content, 'SpecificType') ?? 'unknown';
  }

  List<ColorInfo> _parseColors(String content) {
    final regex = RegExp(r'Colors:\s*(.+)', caseSensitive: false);
    final match = regex.firstMatch(content);

    if (match == null) return [];

    final colorLine = match.group(1)?.split('\n').first ?? '';
    final parts = colorLine.split(';');

    final colors = <ColorInfo>[];

    for (final part in parts) {
      final cleanedPart = part.replaceAll('%', '').trim();
      final values = cleanedPart.split(',').map((e) {
        final cleaned = e.trim();
        return int.tryParse(cleaned) ?? -1;
      }).toList();
      
      if (values.length == 4 && !values.contains(-1)) {
        colors.add(ColorInfo(r: values[0], g: values[1], b: values[2], pct: values[3]));
      }
    }

    return colors;
  }

  String _parseBrand(String content) {
    return _parseField(content, 'Brand') ?? 'unknown';
  }

  String _parseProduct(String content) {
    return _parseField(content, 'Product') ?? 'unknown';
  }

  String? _parseField(String content, String field) {
    final regex = RegExp('$field:\\s*(.+)', caseSensitive: false);
    final match = regex.firstMatch(content);

    if (match == null) return null;

    final value = match.group(1)?.trim() ?? '';
    return value.split('\n').first.trim();
  }
}

class AnalysisResult {
  final String type;
  final String specificType;
  final List<ColorInfo> colors;
  final String brand;
  final String product;
  final String? imageUrl;
  final String? imageBase64;

  AnalysisResult({
    required this.type,
    this.specificType = 'unknown',
    required this.colors,
    required this.brand,
    required this.product,
    this.imageUrl,
    this.imageBase64,
  });
}
