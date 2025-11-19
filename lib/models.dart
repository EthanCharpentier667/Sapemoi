import 'package:sapemoi/network_manager.dart';

class Clothing {
  int id;
  String name;
  String imagePath;
  String? imageBase64;
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
    required this.imagePath,
    this.imageBase64,
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
      'imagePath': imagePath,
      'imageBase64': imageBase64,
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
    final colorString = map['colors'] as String;
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

    return Clothing(
      id: map['id'] as int,
      name: map['name'] as String,
      imagePath: map['imagePath'] as String,
      imageBase64: map['imageBase64'] as String?,
      type: map['type'] as String,
      specificType: map['specificType'] as String? ?? 'unknown',
      colors: colors.isEmpty ? [ColorInfo(r: 128, g: 128, b: 128, pct: 100)] : colors,
      brand: map['brand'] as String? ?? 'unknown',
      productName: map['productName'] as String? ?? 'unknown',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      wearCount: map['wearCount'] as int? ?? 0,
      lastWorn: map['lastWorn'] != null ? DateTime.fromMillisecondsSinceEpoch(map['lastWorn'] as int) : null,
      estimatedValue: map['estimatedValue'] as double?,
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
}

class MissingPieceRecommendation {
  final String type;
  final String specificType;
  final List<String> suggestedBrands;
  final ColorInfo targetColor;
  final List<Clothing> existingOutfit;
  final double currentScore;
  final double potentialScore;
  final String reason;
  final List<String> searchKeywords;

  MissingPieceRecommendation({
    required this.type,
    required this.specificType,
    required this.suggestedBrands,
    required this.targetColor,
    required this.existingOutfit,
    required this.currentScore,
    required this.potentialScore,
    required this.reason,
    required this.searchKeywords,
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
    };
  }
}
