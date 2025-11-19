import 'dart:math';
import 'models.dart';
import 'outfit_generator.dart';
import 'color_utils.dart';
import 'network_manager.dart';

class RecommendationEngine {
  static Future<List<MissingPieceRecommendation>> generateRecommendations(
    List<Clothing> allClothes,
    StyleProfile userStyle, {
    int maxRecommendations = 5,
    bool boldMode = false,
  }) async {
    final recommendations = <MissingPieceRecommendation>[];
    final random = Random();

    final optionalTypes = ['footwear', 'outerwear', 'headwear', 'accessory'];
    
    final byType = <String, List<Clothing>>{};
    for (final item in allClothes) {
      byType.putIfAbsent(item.type.toLowerCase(), () => []).add(item);
    }

    if (!byType.containsKey('top') || !byType.containsKey('bottom')) {
      return recommendations;
    }

    var attempts = 0;
    const maxAttempts = 100;

    while (recommendations.length < maxRecommendations && attempts < maxAttempts) {
      attempts++;

      final missingType = optionalTypes[random.nextInt(optionalTypes.length)];
      
      final fullOutfit = <Clothing>[];
      
      if (byType['top']!.isNotEmpty) {
        fullOutfit.add(byType['top']![random.nextInt(byType['top']!.length)]);
      }
      
      if (byType['bottom']!.isNotEmpty) {
        fullOutfit.add(byType['bottom']![random.nextInt(byType['bottom']!.length)]);
      }
      
      for (final type in byType.keys) {
        if (type != 'top' && type != 'bottom' && type != missingType) {
          if (byType[type]!.isNotEmpty && random.nextDouble() > 0.3) {
            fullOutfit.add(byType[type]![random.nextInt(byType[type]!.length)]);
          }
        }
      }

      if (fullOutfit.length < 2) continue;

      
      final currentResult = OutfitGenerator.evaluateOutfitWithWeights(fullOutfit, boldMode: boldMode);
      final currentScore = 100 - currentResult.score;

      
      if (currentScore < 70 || currentScore > 90) continue;

      
      final targetColor = _findMissingColorForPerfectRecall(fullOutfit);
      
      if (targetColor == null) continue;

      
      final specificType = _suggestSpecificType(missingType, userStyle);

      List<Map<String, dynamic>> remoteItems = [];
      try {
        final criteriaString = 'missingType:$missingType';
        remoteItems = await NetworkManager().recommendClothingItems(userStyle.styleType, criteriaString);
      } catch (e) {
        remoteItems = [];
      }

      List<String> suggestedBrands = _suggestBrands(missingType, userStyle);
      String reason = 'Recommended based on your style';
      List<String> keywords = _generateSearchKeywords(missingType, specificType, targetColor, suggestedBrands);
      double potentialScore = min(98.0, currentScore + 15 + random.nextDouble() * 10);

      if (remoteItems.isNotEmpty) {
        final first = remoteItems.first;
        if (first['brand'] != null) {
          suggestedBrands = [ (first['brand'] as String).toLowerCase() ];
        }
        if (first['colors'] != null) {
          final colorField = first['colors'] as String;
          final firstColor = colorField.split(';').first.trim();
          final vals = firstColor.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();
          if (vals.length >= 3) {
            final remoteColor = ColorInfo(r: vals[0], g: vals[1], b: vals[2], pct: 100);
            final recommendation = MissingPieceRecommendation(
              type: missingType,
              specificType: first['specificType'] ?? specificType,
              suggestedBrands: suggestedBrands,
              targetColor: remoteColor,
              existingOutfit: fullOutfit,
              currentScore: currentScore,
              potentialScore: potentialScore,
              reason: first['reason'] ?? reason,
              searchKeywords: keywords,
            );

            final isDuplicate = recommendations.any((r) =>
              r.type == recommendation.type &&
              r.targetColor.r == recommendation.targetColor.r &&
              r.targetColor.g == recommendation.targetColor.g &&
              r.targetColor.b == recommendation.targetColor.b);

            if (!isDuplicate) recommendations.add(recommendation);
            continue;
          }
        }
        final recommendation = MissingPieceRecommendation(
          type: missingType,
          specificType: remoteItems.first['specificType'] ?? specificType,
          suggestedBrands: suggestedBrands,
          targetColor: targetColor,
          existingOutfit: fullOutfit,
          currentScore: currentScore,
          potentialScore: potentialScore,
          reason: remoteItems.first['reason'] ?? reason,
          searchKeywords: keywords,
        );

        final isDuplicate = recommendations.any((r) =>
          r.type == recommendation.type &&
          r.targetColor.r == recommendation.targetColor.r &&
          r.targetColor.g == recommendation.targetColor.g &&
          r.targetColor.b == recommendation.targetColor.b);

        if (!isDuplicate) recommendations.add(recommendation);
        continue;
      }

      final suggestedBrandsLocal = _suggestBrands(missingType, userStyle);
      final reasonLocal = 'Recommended based on your style';
      final keywordsLocal = _generateSearchKeywords(missingType, specificType, targetColor, suggestedBrandsLocal);
      final potentialScoreLocal = min(98.0, currentScore + 15 + random.nextDouble() * 10);

      final recommendation = MissingPieceRecommendation(
        type: missingType,
        specificType: specificType,
        suggestedBrands: suggestedBrandsLocal,
        targetColor: targetColor,
        existingOutfit: fullOutfit,
        currentScore: currentScore,
        potentialScore: potentialScoreLocal,
        reason: reasonLocal,
        searchKeywords: keywordsLocal,
      );

      
      final isDuplicate = recommendations.any((r) => 
        r.type == recommendation.type &&
        r.targetColor.r == recommendation.targetColor.r &&
        r.targetColor.g == recommendation.targetColor.g &&
        r.targetColor.b == recommendation.targetColor.b
      );

      if (!isDuplicate) {
        recommendations.add(recommendation);
      }
    }

    recommendations.sort((a, b) => b.potentialScore.compareTo(a.potentialScore));

    return recommendations;
  }
  
  static ColorInfo? _findMissingColorForPerfectRecall(List<Clothing> outfit) {

    final existingColors = <ColorInfo>[];
    for (final item in outfit) {
      for (final color in item.colors) {
        if (color.pct >= 20) {
          existingColors.add(color);
        }
      }
    }

    if (existingColors.isEmpty) return null;

    for (final color in existingColors) {
      if (color.pct >= 20 && color.pct <= 40) {
        
        final r = color.r / 255.0;
        final g = color.g / 255.0;
        final b = color.b / 255.0;
        
        if (!isNeutral(r, g, b)) {
          return ColorInfo(r: color.r, g: color.g, b: color.b, pct: 100);
        }
      }
    }

    
    final dominantColor = existingColors.reduce((a, b) => a.pct > b.pct ? a : b);
    final hsl = rgbToHsl(
      dominantColor.r / 255.0,
      dominantColor.g / 255.0,
      dominantColor.b / 255.0,
    );
    
    
    var complementaryHue = (hsl.h + 180) % 360;
    final complementaryRgb = hslToRgb(complementaryHue, hsl.s, hsl.l);
    
    return ColorInfo(
      r: (complementaryRgb.$1 * 255).round(),
      g: (complementaryRgb.$2 * 255).round(),
      b: (complementaryRgb.$3 * 255).round(),
      pct: 100,
    );
  }

  static String _suggestSpecificType(String type, StyleProfile userStyle) {
    if (userStyle.topTypes.isNotEmpty) {
      for (final topType in userStyle.topTypes) {
        if (topType.contains(_getTypeKeyword(type))) {
          return topType;
        }
      }
    }
    return _getTypeKeyword(type);
  }

  static String _getTypeKeyword(String type) {
    switch (type.toLowerCase()) {
      case 'footwear': return 'sneakers';
      case 'outerwear': return 'hoodie';
      case 'headwear': return 'cap';
      case 'accessory': return 'bag';
      default: return type;
    }
  }

  static List<String> _suggestBrands(String type, StyleProfile userStyle) {
    final suggestions = <String>[];

    if (userStyle.topBrands.isNotEmpty) {
      suggestions.addAll(userStyle.topBrands.take(2));
    }

    return suggestions.toSet().take(3).toList();
  }

  static String _getColorName(ColorInfo color) {
    final r = color.r;
    final g = color.g;
    final b = color.b;

    if (r < 50 && g < 50 && b < 50) return 'noir';
    
    if (r > 200 && g > 200 && b > 200) return 'blanc';
    
    // Gris
    if ((r - g).abs() < 30 && (g - b).abs() < 30 && (r - b).abs() < 30) {
      return 'gris';
    }

    // Rouge
    if (r > g + 50 && r > b + 50) return 'rouge';
    
    // Bleu
    if (b > r + 50 && b > g + 50) return 'bleu';
    
    // Vert
    if (g > r + 50 && g > b + 50) return 'vert';
    
    // Jaune
    if (r > 200 && g > 200 && b < 100) return 'jaune';
    
    // Orange
    if (r > 200 && g > 100 && g < 200 && b < 100) return 'orange';
    
    // Rose
    if (r > 200 && g < 150 && b > 150) return 'rose';
    
    // Violet
    if (r > 100 && b > 100 && g < 100) return 'violet';
    
    // Marron
    if (r > 100 && g > 50 && b < 100) return 'marron';
    
    return 'coloré';
  }

  static List<String> _generateSearchKeywords(
    String type,
    String specificType,
    ColorInfo color,
    List<String> brands,
  ) {
    final keywords = <String>[];
    
    keywords.add(specificType);
    
    final colorName = _getColorName(color);
    keywords.add(colorName);
    keywords.add('$specificType $colorName');
    
    if (brands.isNotEmpty) {
      keywords.add('${brands.first} $specificType');
      keywords.add('${brands.first} $colorName');
    }
    
    return keywords.take(5).toList();
  }
}
