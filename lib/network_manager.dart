import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  final String endpoint = 'https://sapemoi-api.onrender.com/analyze';
  final String totalEndpoint = 'https://sapemoi-api.onrender.com/total';
  final String styleEndpoint =
      'https://sapemoi-api.onrender.com/analyse_user_style';
  final String recommendEndpoint =
      'https://sapemoi-api.onrender.com/recomands_clothing_items';

  Future<Map<String, dynamic>> estimateWardrobeValue(
    List<Map<String, dynamic>> items, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    try {
      print('🔄 Estimating wardrobe value for ${items.length} items');

      final payload = {
        'items': items
            .map(
              (item) => {
                'brand': item['brand'],
                'product': item['product'],
                'type': item['type'],
                'specificType': item['specificType'],
              },
            )
            .toList(),
      };
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

      print('✅ Wardrobe value estimated: \$$total');
      return {'total': total.toDouble(), 'breakdown': breakdown ?? []};
    } catch (e) {
      print('❌ Network error: $e');
      rethrow;
    }
  }

  Future<String> estimateUserStyle(
    List<Map<String, dynamic>> items, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    try {
      print('🔄 Estimating user style for ${items.length} items');

      final itemsArray = items
          .map(
            (item) => {
              'brand': item['brand'],
              'product': item['product'],
              'type': item['type'],
              'specificType': item['specificType'],
            },
          )
          .toList();

      final payload = {
        'itemsList': json.encode(itemsArray),
      };

      final body = json.encode(payload);

      final response = await http
          .post(
            Uri.parse(styleEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);

      print('📥 Style response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final jsonData = json.decode(response.body) as Map<String, dynamic>;

      if (jsonData.containsKey('error')) {
        throw Exception('API Error: ${jsonData['error']}');
      }

      final estimated = jsonData['estimatedStyle'] as String?;
      if (estimated == null || estimated.isEmpty) {
        return 'Major style: "casual"';
      }

      print('✅ Style estimated: $estimated');
      return estimated;
    } catch (e) {
      print('❌ Network error while estimating style: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> recommendClothingItems(
    String userStyle,
    dynamic criteria, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    try {
      print('🔄 Requesting clothing recommendations for style="$userStyle" criteria="$criteria"');

      final dynamic payloadCriteria;
      if (criteria is String) {
        payloadCriteria = criteria;
      } else {
        payloadCriteria = criteria;
      }

      final payload = {'userStyle': userStyle, 'criteria': payloadCriteria};

      final body = json.encode(payload);

      final response = await http
          .post(
            Uri.parse(recommendEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);

      print('📥 Recommend response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final jsonData = json.decode(response.body);

      if (jsonData is Map<String, dynamic>) {
        if (jsonData['recommendations'] is List) {
          return List<Map<String, dynamic>>.from(jsonData['recommendations']);
        }
        if (jsonData['data'] is List) {
          return List<Map<String, dynamic>>.from(jsonData['data']);
        }
        return [Map<String, dynamic>.from(jsonData)];
      }

      if (jsonData is List) {
        return List<Map<String, dynamic>>.from(
          jsonData.map((e) => Map<String, dynamic>.from(e)),
        );
      }

      try {
        final parsed = json.decode(response.body);
        if (parsed is List) {
          return List<Map<String, dynamic>>.from(
            parsed.map((e) => Map<String, dynamic>.from(e)),
          );
        }
      } catch (_) {}

      return [
        {'raw': response.body},
      ];
    } catch (e) {
      print('❌ Network error while requesting recommendations: $e');
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
          throw Exception(
            'Not a clothing item. Please upload an image of clothing, footwear, or fashion accessories.',
          );
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

      print(
        '✅ Parsed - type: $type, specificType: $specificType, colors: ${colors.length}, brand: $brand, product: $product',
      );

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
        colors.add(
          ColorInfo(r: values[0], g: values[1], b: values[2], pct: values[3]),
        );
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

  AnalysisResult({
    required this.type,
    this.specificType = 'unknown',
    required this.colors,
    required this.brand,
    required this.product,
  });
}
