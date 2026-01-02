import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  static const String render = 'https://sapemoi-api.onrender.com';
  static const String droplet = 'http://164.92.204.32:3000';
  static const String actual = droplet;

  final String endpoint = '$actual/analyze';
  final String totalEndpoint = '$actual/total';
  final String styleEndpoint = '$actual/analyse_user_style';
  final String recommendEndpoint = '$actual/recomands_clothing_items';
  final String googleSearchEndpoint = '$actual/google_search';
  final String remoteApiBase = '$actual/db';

  // --- Remote DB API helpers (Render endpoints)
  Future<bool> upsertUser(Map<String, dynamic> user) async {
    try {
      final url = Uri.parse('$remoteApiBase/users');
      final body = json.encode(user);
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Update only the styleProfile field for a user (doesn't overwrite other fields)
  Future<bool> updateUserStyleProfile(String uid, String styleProfileJson) async {
    try {
      final url = Uri.parse('$remoteApiBase/users/$uid/style');
      final body = json.encode({'styleProfile': styleProfileJson});
      final resp = await http
          .put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUserRemote(String uid) async {
    try {
      final url = Uri.parse('$remoteApiBase/users/$uid');
      final resp = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final jsonData = json.decode(resp.body);
      if (jsonData is Map<String, dynamic>) return jsonData;
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserStyleRemote(String uid) async {
    final stopwatch = Stopwatch()..start();
    try {
      final url = Uri.parse('$remoteApiBase/users/$uid/style');
      final resp = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));
      stopwatch.stop();
      print('⏱️ getUserStyleRemote took ${stopwatch.elapsedMilliseconds}ms');
      if (resp.statusCode != 200) return null;
      final jsonData = json.decode(resp.body) as Map<String, dynamic>;
      final styleProfile = jsonData['styleProfile'];
      
      // If styleProfile is null or empty, return null (user hasn't estimated style yet)
      if (styleProfile == null) return null;
      
      if (styleProfile is String) {
        if (styleProfile.isEmpty) return null;
        try {
          return json.decode(styleProfile) as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      }
      
      if (styleProfile is Map<String, dynamic>) return styleProfile;
      
      return null;
    } catch (e) {

      return null;
    }
  }

  Future<int?> addClothingRemote(Map<String, dynamic> payload) async {
    try {
      final url = Uri.parse('$remoteApiBase/clothing');
      final body = json.encode(payload);
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final jsonData = json.decode(resp.body) as Map<String, dynamic>;
      return jsonData['id'] as int?;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllClothingRemote(String userId) async {
    final stopwatch = Stopwatch()..start();
    try {
      final url = Uri.parse('$remoteApiBase/clothing/$userId');
      final resp = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));
      stopwatch.stop();
      print('⏱️ getAllClothingRemote took ${stopwatch.elapsedMilliseconds}ms');
      if (resp.statusCode != 200) return [];
      final jsonData = json.decode(resp.body);
      if (jsonData is List) return List<Map<String, dynamic>>.from(jsonData);
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<String?> uploadImage(String base64Image, [String folder = 'clothing']) async {
    try {
      final url = Uri.parse('$remoteApiBase/upload');
      final bytes = base64Decode(base64Image);
      
      final request = http.MultipartRequest('POST', url);
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: '${folder}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      
      final response = await request.send().timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      
      final responseBody = await response.stream.bytesToString();
      final jsonData = json.decode(responseBody) as Map<String, dynamic>;
      return jsonData['imageUrl'] as String?;
    } catch (e) {
      print('❌ Error uploading image: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateClothingRemote(
    int id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final url = Uri.parse('$remoteApiBase/clothing/$id');
      final resp = await http
          .put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(updates),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      return json.decode(resp.body) as Map<String, dynamic>;
    } catch (e) {

      return null;
    }
  }

  Future<bool> deleteClothingRemote(int id) async {
    try {
      final url = Uri.parse('$remoteApiBase/clothing/$id');
      final resp = await http.delete(url).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {

      return false;
    }
  }

  Future<bool> markOutfitUsedRemote(
    List<int> clothingIds,
    String userId,
  ) async {
    try {
      final url = Uri.parse('$remoteApiBase/outfit/mark_used');
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'clothingIds': clothingIds, 'userId': userId}),
          )
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {

      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getRecentOutfitsRemote(
    String userId, {
    int limit = 10,
  }) async {
    try {
      final url = Uri.parse(
        '$remoteApiBase/outfit/recent/$userId?limit=$limit',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return [];
      final jsonData = json.decode(resp.body);
      if (jsonData is List) return List<Map<String, dynamic>>.from(jsonData);
      return [];
    } catch (e) {

      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getWearStatsRemote(String userId) async {
    try {
      final url = Uri.parse('$remoteApiBase/clothing/wear_stats/$userId');
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return [];
      final jsonData = json.decode(resp.body);
      if (jsonData is List) return List<Map<String, dynamic>>.from(jsonData);
      return [];
    } catch (e) {

      return [];
    }
  }

  Future<bool> updateClothingValueRemote(int id, double value) async {
    try {
      final url = Uri.parse('$remoteApiBase/clothing/$id/value');
      final resp = await http
          .put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'value': value}),
          )
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {

      return false;
    }
  }

  Future<double> getTotalWardrobeValueRemote(String userId) async {
    final stopwatch = Stopwatch()..start();
    try {
      final url = Uri.parse('$remoteApiBase/clothing/total_value/$userId');
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      stopwatch.stop();
      print('⏱️ getTotalWardrobeValueRemote took ${stopwatch.elapsedMilliseconds}ms');
      if (resp.statusCode != 200) return 0.0;
      final jsonData = json.decode(resp.body) as Map<String, dynamic>;
      final total = jsonData['total'];
      if (total is num) return total.toDouble();
      return 0.0;
    } catch (e) {

      return 0.0;
    }
  }

  Future<List<int>> getUnvaluedClothingIdsRemote(String userId) async {
    try {
      final url = Uri.parse('$remoteApiBase/clothing/unvalued/$userId');
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return [];
      final jsonData = json.decode(resp.body);
      if (jsonData is List)
        return List<int>.from(jsonData.map((e) => e as int));
      return [];
    } catch (e) {

      return [];
    }
  }

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

      final payload = {'itemsList': json.encode(itemsArray)};

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
      print(
        '🔄 Requesting clothing recommendations for style="$userStyle" criteria="$criteria"',
      );

      final dynamic payloadCriteria;
      if (criteria is String) {
        payloadCriteria = criteria;
      } else {
        payloadCriteria = criteria;
      }

      final payload = {'userStyle': userStyle, 'criterias': payloadCriteria};

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
    String imageUrl, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final payload = {'imageUrl': imageUrl};
      final body = json.encode(payload);

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);

      print('📥 Analysis request: $body');
      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final jsonData = json.decode(response.body) as Map<String, dynamic>;

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

      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;

      if (content == null) {
        throw Exception('Missing message or content in choices');
      }

      final type = _parseType(content);
      final specificType = _parseSpecificType(content);
      final layer = _parseLayer(content);
      final colors = _parseColors(content);
      final brand = _parseBrand(content);
      final product = _parseProduct(content);

      stopwatch.stop();
      print('⏱️ Analysis took ${stopwatch.elapsed.inSeconds}s (${stopwatch.elapsed.inMilliseconds}ms)');

      return AnalysisResult(
        type: type,
        specificType: specificType,
        layer: layer,
        colors: colors,
        brand: brand,
        product: product,
      );
    } catch (e) {
      print('❌ Network error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> googleSearch(
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      print('🔎 Google search payload: $payload');
      final body = json.encode(payload);
      final response = await http
          .post(
            Uri.parse(googleSearchEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);

      print('📥 Google search status: ${response.statusCode}');
      print('📥 Google search body: ${response.body}');
      if (response.statusCode != 200) {
        print('⚠️ Google search failed: ${response.body}');
        return null;
      }

      final jsonData = json.decode(response.body);
      print('📦 Parsed google_search jsonData type=${jsonData.runtimeType}');
      if (jsonData == null) return null;

      if (jsonData is List && jsonData.isNotEmpty) {
        final first = jsonData.first;
        final Map<String, dynamic> raw = first is Map<String, dynamic>
            ? first
            : Map<String, dynamic>.from(first as Map);
        final normalized = <String, dynamic>{
          'Name':
              raw['Name'] ??
              raw['name'] ??
              raw['title'] ??
              raw['product'] ??
              '',
          'ImageURL':
              raw['ImageURL'] ??
              raw['imageUrl'] ??
              raw['image'] ??
              raw['thumbnail'] ??
              '',
          'url':
              raw['formattedUrl'] ??
              raw['url'] ??
              raw['link'] ??
              raw['source'] ??
              '',
          'Shopify':
              raw['Shopify'] ??
              raw['shopify'] ??
              raw['ShopifyLink'] ??
              raw['shopify_link'] ??
              null,
        };
        print('✅ Returning normalized google result: $normalized');
        return normalized;
      }

      if (jsonData is Map<String, dynamic>) {
        Map<String, dynamic> raw;
        if (jsonData.containsKey('result') && jsonData['result'] is Map) {
          raw = Map<String, dynamic>.from(jsonData['result'] as Map);
          print('ℹ️ google_search: extracted nested "result" map');
        } else if (jsonData.containsKey('results') &&
            jsonData['results'] is List &&
            (jsonData['results'] as List).isNotEmpty) {
          raw = Map<String, dynamic>.from(
            (jsonData['results'] as List).first as Map,
          );
          print(
            'ℹ️ google_search: extracted first element from "results" list',
          );
        } else if (jsonData.containsKey('data') && jsonData['data'] is Map) {
          raw = Map<String, dynamic>.from(jsonData['data'] as Map);
          print('ℹ️ google_search: extracted nested "data" map');
        } else {
          raw = Map<String, dynamic>.from(jsonData);
          print('ℹ️ google_search: using top-level map');
        }

        final normalized = <String, dynamic>{
          'Name':
              raw['Name'] ??
              raw['name'] ??
              raw['title'] ??
              raw['product'] ??
              '',
          'ImageURL':
              raw['ImageURL'] ??
              raw['imageUrl'] ??
              raw['image'] ??
              raw['thumbnail'] ??
              '',
          'url':
              raw['formattedUrl'] ??
              raw['url'] ??
              raw['link'] ??
              raw['source'] ??
              '',
          'Shopify':
              raw['Shopify'] ??
              raw['shopify'] ??
              raw['ShopifyLink'] ??
              raw['shopify_link'] ??
              null,
        };
        print('✅ Returning normalized google result (from map): $normalized');
        return normalized;
      }

      try {
        return Map<String, dynamic>.from(json.decode(response.body));
      } catch (_) {
        return null;
      }
    } catch (e) {
      print('❌ Error calling google_search: $e');
      return null;
    }
  }

  String _parseType(String content) {
    return _parseField(content, 'Type') ?? 'unknown';
  }

  String _parseSpecificType(String content) {
    return _parseField(content, 'SpecificType') ?? 'unknown';
  }

  int _parseLayer(String content) {
    final layerStr = _parseField(content, 'Layer');
    return int.tryParse(layerStr ?? '1') ?? 1;
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

  // --- Feed Social API ---
  Future<int?> createOutfitPostRemote({
    required String userId,
    required String imageUrl,
    required String description,
    required List<int> clothingIds,
  }) async {
    try {
      final url = Uri.parse('$remoteApiBase/outfit-posts');
      final body = json.encode({
        'userId': userId,
        'imageUrl': imageUrl,
        'description': description,
        'clothingIds': clothingIds,
      });
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));
      
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final jsonData = json.decode(resp.body);
        return jsonData['id'] as int?;
      }
      return null;
    } catch (e) {
      print('Error creating outfit post: $e');
      return null;
    }
  }

  Future<List<OutfitPost>> getFeedPostsRemote(String currentUserId, {int limit = 50}) async {
    try {
      final url = Uri.parse('$remoteApiBase/outfit-posts/feed?userId=$currentUserId&limit=$limit');
      final resp = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));
      
      if (resp.statusCode != 200) return [];
      
      final List<dynamic> jsonData = json.decode(resp.body);
      final List<OutfitPost> posts = [];
      
      for (final postData in jsonData) {
        try {
          // Get clothing items for this post
          final clothingIds = (postData['clothing_ids'] ?? postData['clothingIds']) as List<dynamic>?;
          final List<Clothing> items = [];
          
          if (clothingIds != null) {
            for (final id in clothingIds) {
              final clothingData = await getClothingByIdRemote(id as int);
              if (clothingData != null) {
                items.add(Clothing.fromMap(clothingData));
              }
            }
          }
          
          posts.add(OutfitPost.fromMap(postData as Map<String, dynamic>, items));
        } catch (e) {
          print('Error parsing post: $e');
        }
      }
      
      return posts;
    } catch (e) {
      print('Error getting feed posts: $e');
      return [];
    }
  }

  Future<void> toggleLikePostRemote(int postId, String userId) async {
    try {
      final url = Uri.parse('$remoteApiBase/outfit-posts/$postId/like');
      final body = json.encode({'userId': userId});
      await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  Future<List<OutfitPost>> getUserPostsRemote(String userId, {int limit = 20}) async {
    try {
      final url = Uri.parse('$remoteApiBase/outfit-posts/user/$userId?limit=$limit');
      final resp = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));
      
      if (resp.statusCode != 200) return [];
      
      final List<dynamic> jsonData = json.decode(resp.body);
      final List<OutfitPost> posts = [];
      
      for (final postData in jsonData) {
        try {
          final clothingIds = (postData['clothing_ids'] ?? postData['clothingIds']) as List<dynamic>?;
          final List<Clothing> items = [];
          
          if (clothingIds != null) {
            for (final id in clothingIds) {
              final clothingData = await getClothingByIdRemote(id as int);
              if (clothingData != null) {
                items.add(Clothing.fromMap(clothingData));
              }
            }
          }
          
          posts.add(OutfitPost.fromMap(postData as Map<String, dynamic>, items));
        } catch (e) {
          print('Error parsing user post: $e');
        }
      }
      
      return posts;
    } catch (e) {
      print('Error getting user posts: $e');
      return [];
    }
  }

  Future<void> deleteOutfitPostRemote(int postId, String userId) async {
    try {
      final url = Uri.parse('$remoteApiBase/outfit-posts/$postId');
      final body = jsonEncode({'userId': userId});
      await http
          .delete(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      print('Error deleting post: $e');
    }
  }

  Future<void> clearWornOutfitsRemote(String userId) async {
    try {
      final url = Uri.parse('$remoteApiBase/worn-outfits/clear');
      final body = jsonEncode({'userId': userId});
      await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      print('Error clearing worn outfits: $e');
    }
  }

  Future<Map<String, dynamic>?> getClothingByIdRemote(int id) async {
    try {
      final url = Uri.parse('$remoteApiBase/clothing/$id');
      final resp = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));
      
      if (resp.statusCode != 200) return null;
      
      final decoded = json.decode(resp.body);
      
      if (decoded is List && decoded.isNotEmpty) {
        return decoded[0] as Map<String, dynamic>;
      }
      
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      
      return null;
    } catch (e) {
      print('Error getting clothing by ID: $e');
      return null;
    }
  }
}

class AnalysisResult {
  final String type;
  final String specificType;
  final int layer;
  final List<ColorInfo> colors;
  final String brand;
  final String product;

  AnalysisResult({
    required this.type,
    this.specificType = 'unknown',
    this.layer = 1,
    required this.colors,
    required this.brand,
    required this.product,
  });
}
