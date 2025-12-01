import 'package:sapemoi/network_manager.dart';

class Clothing {
  int id;
  String name;
  String imageUrl;
  String type;
  String specificType;
  List<ColorInfo> colors;
  String brand;
  String productName;
  DateTime createdAt;
  int wearCount;
  DateTime? lastWorn;
  double? estimatedValue;

  Clothing({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.type,
    this.specificType = 'unknown',
    required this.colors,
    this.brand = 'unknown',
    this.productName = 'unknown',
    required this.createdAt,
    this.wearCount = 0,
    this.lastWorn,
    this.estimatedValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'type': type,
      'specificType': specificType,
      'colors': colors.map((c) => '${c.r},${c.g},${c.b},${c.pct}').join(';'),
      'brand': brand,
      'productName': productName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'wearCount': wearCount,
      'lastWorn': lastWorn?.millisecondsSinceEpoch,
      'estimatedValue': estimatedValue,
    };
  }

  factory Clothing.fromMap(Map<String, dynamic> map) {
    final colorString = (map['colors'] ?? '') as String;
    final colorParts = colorString.split(';');
    final colors = colorParts.map((part) {
      final cleanedPart = part.replaceAll('%', '').trim();
      final values = cleanedPart.split(',').map((e) {
        final cleaned = e.trim();
        return int.tryParse(cleaned) ?? 0;
      }).toList();
      
      if (values.length == 4) {
        return ColorInfo(r: values[0], g: values[1], b: values[2], pct: values[3]);
      }
      return ColorInfo(r: 0, g: 0, b: 0, pct: 0);
    }).where((c) => c.pct > 0).toList();

    // Helper to get field (try camelCase first, then lowercase)
    T? getField<T>(String camelCase, String lowercase) {
      return (map[camelCase] ?? map[lowercase]) as T?;
    }

    final createdAtRaw = getField<dynamic>('createdAt', 'createdat');
    int createdAtMs;
    if (createdAtRaw is int) {
      createdAtMs = createdAtRaw;
    } else if (createdAtRaw is String) {
      createdAtMs = int.tryParse(createdAtRaw) ?? DateTime.now().millisecondsSinceEpoch;
    } else {
      createdAtMs = DateTime.now().millisecondsSinceEpoch;
    }

    final lastWornRaw = getField<dynamic>('lastWorn', 'lastworn');
    int? lastWornMs;
    if (lastWornRaw is int) {
      lastWornMs = lastWornRaw;
    } else if (lastWornRaw is String) {
      lastWornMs = int.tryParse(lastWornRaw);
    }

    return Clothing(
      id: map['id'] as int,
      name: map['name'] as String,
      imageUrl: getField<String>('imageUrl', 'imageurl') ?? '',
      type: map['type'] as String,
      specificType: getField<String>('specificType', 'specifictype') ?? 'unknown',
      colors: colors.isEmpty ? [ColorInfo(r: 128, g: 128, b: 128, pct: 100)] : colors,
      brand: map['brand'] as String? ?? 'unknown',
      productName: getField<String>('productName', 'productname') ?? 'unknown',
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
      wearCount: getField<int>('wearCount', 'wearcount') ?? 0,
      lastWorn: lastWornMs != null ? DateTime.fromMillisecondsSinceEpoch(lastWornMs) : null,
      estimatedValue: getField<num>('estimatedValue', 'estimatedvalue')?.toDouble(),
    );
  }
}

class ColorInfo {
  final int r;
  final int g;
  final int b;
  final int pct;

  ColorInfo({
    required this.r,
    required this.g,
    required this.b,
    required this.pct,
  });
}

class OutfitResult {
  final bool valid;
  final double score;
  final List<ColorClash> clashes;

  OutfitResult({
    required this.valid,
    required this.score,
    required this.clashes,
  });
}

class ColorClash {
  final String type1;
  final ColorInfo color1;
  final String type2;
  final ColorInfo color2;
  final double score;

  ColorClash({
    required this.type1,
    required this.color1,
    required this.type2,
    required this.color2,
    required this.score,
  });
}

class StyleProfile {
  final String styleType;
  final Map<String, int> brandPreferences;
  final Map<String, int> typePreferences;
  final Map<String, int> colorPreferences;
  final List<String> topBrands;
  final List<String> topTypes;
  final List<String> allBrands;
  final List<String> allSpecificTypes;
  final List<ColorInfo> topColors;

  StyleProfile({
    this.styleType = 'casual',
    required this.brandPreferences,
    required this.typePreferences,
    required this.colorPreferences,
    required this.topBrands,
    required this.topTypes,
    required this.allBrands,
    required this.allSpecificTypes,
    required this.topColors,
  });

  static Future<StyleProfile> fromClothes(List<Clothing> clothes) async {
    final brandMap = <String, int>{};
    final typeMap = <String, int>{};
    final colorMap = <String, int>{};
    final allBrands = <String>{};
    final allSpecificTypes = <String>{};

    for (final item in clothes) {
      final brand = item.brand.toLowerCase();
      if (brand != 'unknown') {
        brandMap[brand] = (brandMap[brand] ?? 0) + (item.wearCount > 0 ? item.wearCount : 1);
        allBrands.add(brand);
      }

      final type = item.specificType.toLowerCase();
      if (type != 'unknown') {
        typeMap[type] = (typeMap[type] ?? 0) + (item.wearCount > 0 ? item.wearCount : 1);
        allSpecificTypes.add(type);
      }

      for (final color in item.colors) {
        if (color.pct >= 30) {
          final key = '${color.r},${color.g},${color.b}';
          final weight = (color.pct / 100.0 * (item.wearCount > 0 ? item.wearCount : 1)).round();
          colorMap[key] = (colorMap[key] ?? 0) + weight;
        }
      }
    }

    final sortedBrands = brandMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topBrands = sortedBrands.take(3).map((e) => e.key).toList();

    final sortedTypes = typeMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTypes = sortedTypes.take(3).map((e) => e.key).toList();

    final sortedColors = colorMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topColors = sortedColors.take(5).map((e) {
      final parts = e.key.split(',');
      return ColorInfo(
        r: int.parse(parts[0]),
        g: int.parse(parts[1]),
        b: int.parse(parts[2]),
        pct: 100,
      );
    }).toList();

    final items = clothes.map((c) => {
      'brand': c.brand,
      'product': c.productName,
      'type': c.type,
      'specificType': c.specificType,
    }).toList();

    String styleLabel = 'casual';
    try {
      final styleString = await NetworkManager().estimateUserStyle(items);
      final match = RegExp('"([^"]+)"').firstMatch(styleString);
      if (match != null) {
        styleLabel = match.group(1) ?? 'casual';
      } else {
        styleLabel = styleString.split(':').length > 1 ? styleString.split(':')[1].trim() : 'casual';
      }
    } catch (_) {
      styleLabel = 'casual';
    }

    return StyleProfile(
      styleType: styleLabel,
      brandPreferences: brandMap,
      typePreferences: typeMap,
      colorPreferences: colorMap,
      topBrands: topBrands,
      topTypes: topTypes,
      allBrands: allBrands.toList(),
      allSpecificTypes: allSpecificTypes.toList(),
      topColors: topColors,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'styleType': styleType,
      'brandPreferences': brandPreferences,
      'typePreferences': typePreferences,
      'colorPreferences': colorPreferences,
      'topBrands': topBrands,
      'topTypes': topTypes,
      'allBrands': allBrands,
      'allSpecificTypes': allSpecificTypes,
      'topColors': topColors.map((c) => {'r': c.r, 'g': c.g, 'b': c.b, 'pct': c.pct}).toList(),
    };
  }

  factory StyleProfile.fromMap(Map<String, dynamic> map) {
    final topColorsList = <ColorInfo>[];
    if (map['topColors'] is List) {
      for (final c in (map['topColors'] as List)) {
        try {
          topColorsList.add(ColorInfo(
            r: (c['r'] as int?) ?? 128,
            g: (c['g'] as int?) ?? 128,
            b: (c['b'] as int?) ?? 128,
            pct: (c['pct'] as int?) ?? 100,
          ));
        } catch (_) {}
      }
    }

    return StyleProfile(
      styleType: map['styleType'] as String? ?? 'casual',
      brandPreferences: Map<String, int>.from(map['brandPreferences'] ?? {}),
      typePreferences: Map<String, int>.from(map['typePreferences'] ?? {}),
      colorPreferences: Map<String, int>.from(map['colorPreferences'] ?? {}),
      topBrands: (map['topBrands'] as List?)?.map((e) => e.toString()).toList() ?? [],
      topTypes: (map['topTypes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      allBrands: (map['allBrands'] as List?)?.map((e) => e.toString()).toList() ?? [],
      allSpecificTypes: (map['allSpecificTypes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      topColors: topColorsList,
    );
  }
}

class MissingPieceRecommendation {
  final String type;
  final String product;
  final String specificType;
  final List<String> suggestedBrands;
  final ColorInfo targetColor;
  final List<Clothing> existingOutfit;
  final double currentScore;
  final double potentialScore;
  final String reason;
  final List<String> searchKeywords;
  final String googleName;
  final String? googleImageUrl;
  final String? googleUrl;

  MissingPieceRecommendation({
    required this.type,
    required this.product,
    required this.specificType,
    required this.suggestedBrands,
    required this.targetColor,
    required this.existingOutfit,
    required this.currentScore,
    required this.potentialScore,
    required this.reason,
    required this.searchKeywords,
    required this.googleName,
    this.googleImageUrl,
    this.googleUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'specificType': specificType,
      'suggestedBrands': suggestedBrands.join(','),
      'targetColor': '${targetColor.r},${targetColor.g},${targetColor.b}',
      'outfitIds': existingOutfit.map((c) => c.id).join(','),
      'currentScore': currentScore,
      'potentialScore': potentialScore,
      'reason': reason,
      'searchKeywords': searchKeywords.join(','),
      'googleName': googleName,
      'googleImageUrl': googleImageUrl,
      'googleUrl': googleUrl,
    };
  }
}
