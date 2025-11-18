import 'dart:math';
import 'models.dart';
import 'outfit_generator.dart';
import 'color_utils.dart';

class RecommendationEngine {
  static List<MissingPieceRecommendation> generateRecommendations(
    List<Clothing> allClothes,
    StyleProfile userStyle, {
    int maxRecommendations = 5,
    bool boldMode = false,
  }) {
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
      
      // Ajouter les autres types SAUF celui qui va manquer
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
      
      
      final suggestedBrands = _suggestBrands(missingType, userStyle);

      
      final reason = _generateReason(missingType, targetColor, fullOutfit);

      
      final keywords = _generateSearchKeywords(missingType, specificType, targetColor, suggestedBrands);

      
      final potentialScore = min(98.0, currentScore + 15 + random.nextDouble() * 10);

      final recommendation = MissingPieceRecommendation(
        type: missingType,
        specificType: specificType,
        suggestedBrands: suggestedBrands,
        targetColor: targetColor,
        existingOutfit: fullOutfit,
        currentScore: currentScore,
        potentialScore: potentialScore,
        reason: reason,
        searchKeywords: keywords,
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

    // Trier par score potentiel (meilleur en premier)
    recommendations.sort((a, b) => b.potentialScore.compareTo(a.potentialScore));

    return recommendations;
  }

  
  static ColorInfo? _findMissingColorForPerfectRecall(List<Clothing> outfit) {
    // Extraire toutes les couleurs existantes
    final existingColors = <ColorInfo>[];
    for (final item in outfit) {
      for (final color in item.colors) {
        if (color.pct >= 20) { // Couleurs significatives
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

  /// Suggère un type spécifique basé sur le type général et le style de l'utilisateur
  static String _suggestSpecificType(String type, StyleProfile userStyle) {
    // Utiliser les types préférés de l'utilisateur
    if (userStyle.topTypes.isNotEmpty) {
      for (final topType in userStyle.topTypes) {
        if (topType.contains(_getTypeKeyword(type))) {
          return topType;
        }
      }
    }

    // Fallback sur des types génériques par catégorie
    switch (type.toLowerCase()) {
      case 'footwear':
        return userStyle.styleType == 'streetwear' 
          ? 'sneakers montantes' 
          : 'sneakers';
      case 'outerwear':
        return userStyle.styleType == 'streetwear' 
          ? 'hoodie oversize' 
          : 'veste';
      case 'headwear':
        return 'casquette snapback';
      case 'accessory':
        return 'sac bandoulière';
      default:
        return type;
    }
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

  /// Suggère des marques basées sur le profil de style
  static List<String> _suggestBrands(String type, StyleProfile userStyle) {
    final suggestions = <String>[];

    // Utiliser les marques préférées de l'utilisateur
    if (userStyle.topBrands.isNotEmpty) {
      suggestions.addAll(userStyle.topBrands.take(2));
    }

    // Ajouter des marques pertinentes selon le style et le type
    if (type.toLowerCase() == 'footwear') {
      if (userStyle.styleType == 'streetwear') {
        suggestions.addAll(['Nike', 'Jordan', 'New Balance', 'Adidas']);
      } else if (userStyle.styleType == 'luxury') {
        suggestions.addAll(['Balenciaga', 'Common Projects', 'Golden Goose']);
      } else {
        suggestions.addAll(['Vans', 'Converse', 'Nike']);
      }
    } else if (type.toLowerCase() == 'outerwear') {
      if (userStyle.styleType == 'streetwear') {
        suggestions.addAll(['Carhartt', 'Dickies', 'Stüssy']);
      } else {
        suggestions.addAll(['Zara', 'H&M', 'Uniqlo']);
      }
    }

    // Garder unique et limiter à 3
    return suggestions.toSet().take(3).toList();
  }

  /// Génère une raison expliquant pourquoi cette pièce complèterait l'outfit
  static String _generateReason(String type, ColorInfo color, List<Clothing> outfit) {
    final colorName = _getColorName(color);
    
    // Trouver les types dans l'outfit
    final types = outfit.map((c) => c.type).toSet();
    
    if (types.contains('top') && types.contains('bottom')) {
      return 'Un $type $colorName créerait un rappel de couleur parfait entre le haut et le bas, complétant l\'harmonie de l\'outfit';
    } else if (types.contains('top')) {
      return 'Un $type $colorName rappellerait la couleur du haut pour un look cohérent';
    } else {
      return 'Un $type $colorName ajouterait la touche de couleur manquante pour un outfit parfait';
    }
  }

  /// Convertit RGB en nom de couleur approximatif
  static String _getColorName(ColorInfo color) {
    final r = color.r;
    final g = color.g;
    final b = color.b;

    // Noir
    if (r < 50 && g < 50 && b < 50) return 'noir';
    
    // Blanc
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

  /// Génère des mots-clés pour la recherche sur Vinted/Shopify
  static List<String> _generateSearchKeywords(
    String type,
    String specificType,
    ColorInfo color,
    List<String> brands,
  ) {
    final keywords = <String>[];
    
    // Ajouter le type spécifique
    keywords.add(specificType);
    
    // Ajouter la couleur
    final colorName = _getColorName(color);
    keywords.add(colorName);
    keywords.add('$specificType $colorName');
    
    // Ajouter les marques
    if (brands.isNotEmpty) {
      keywords.add('${brands.first} $specificType');
      keywords.add('${brands.first} $colorName');
    }
    
    return keywords.take(5).toList();
  }
}
