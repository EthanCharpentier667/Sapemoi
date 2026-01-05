import 'dart:convert';
import 'dart:math';
import 'models.dart';
import 'outfit_generator.dart';
// color utilities were previously used but selection logic moved into this file
import 'network_manager.dart';

class RecommendationEngine {
  // Simple in-memory cache to avoid redundant remote calls during a session.
  // Key format: '<styleType>|<missingType>|<r>,<g>,<b>'
  static final Map<String, List<Map<String, dynamic>>>
  _remoteRecommendationCache = {};

  /// Clears the in-memory recommendation cache.
  static void clearCache() {
    _remoteRecommendationCache.clear();
  }

  static Future<List<MissingPieceRecommendation>> generateRecommendations(
    List<Clothing> allClothes,
    StyleProfile userStyle, {
    int maxRecommendations = 5,
    bool boldMode = false,
  }) async {
    final recommendations = <MissingPieceRecommendation>[];
    final random = Random();

    final optionalTypes = [
      'footwear',
      'outerwear',
      'headwear',
      'accessory',
      'sweater',
      'top',
      'bottom',
    ];

    final byType = <String, List<Clothing>>{};
    for (final item in allClothes) {
      byType.putIfAbsent(item.type.toLowerCase(), () => []).add(item);
    }

    if (!byType.containsKey('top') || !byType.containsKey('bottom')) {
      return recommendations;
    }

    var attempts = 0;
    const maxAttempts = 100;

    final desiredRecommendations = 1;

    while (recommendations.length < desiredRecommendations &&
        attempts < maxAttempts) {
      attempts++;

      final missingType = optionalTypes[random.nextInt(optionalTypes.length)];

      final fullOutfit = <Clothing>[];

      if (missingType != 'top') {
        if (byType['top'] != null && byType['top']!.isNotEmpty) {
          fullOutfit.add(byType['top']![random.nextInt(byType['top']!.length)]);
        } else {
          continue;
        }
      }

      if (missingType != 'bottom') {
        if (byType['bottom'] != null && byType['bottom']!.isNotEmpty) {
          fullOutfit.add(
            byType['bottom']![random.nextInt(byType['bottom']!.length)],
          );
        } else {
          continue;
        }
      }

      if (missingType != 'footwear') {
        if (byType['footwear'] != null && byType['footwear']!.isNotEmpty) {
          fullOutfit.add(
            byType['footwear']![random.nextInt(byType['footwear']!.length)],
          );
        } else {
          continue;
        }
      }

      for (final type in byType.keys) {
        final t = type.toLowerCase();
        if (t == 'top' || t == 'bottom' || t == missingType || t == 'footwear') {
          continue;
        }
        if (byType[t]!.isNotEmpty && random.nextDouble() > 0.3) {
          fullOutfit.add(byType[t]![random.nextInt(byType[t]!.length)]);
        }
      }

      final currentResult = OutfitGenerator.evaluateOutfitWithWeights(
        fullOutfit,
        boldMode: boldMode,
      );
      final currentScore = 100 - currentResult.score;

      if (currentScore < 70 || currentScore > 90) continue;

      // Determine primary and secondary target colors from the outfit to request
      // recommendations that include a primary color and an accent color.
      final existingColors = <ColorInfo>[];
      for (final item in fullOutfit) {
        for (final c in item.colors) {
          if (c.pct >= 20) existingColors.add(c);
        }
      }

      if (existingColors.isEmpty) continue;

      // aggregate by rgb key and sum pct
      final Map<String, int> colorAgg = {};
      final Map<String, ColorInfo> colorMap = {};
      for (final c in existingColors) {
        final key = '${c.r},${c.g},${c.b}';
        colorAgg[key] = (colorAgg[key] ?? 0) + c.pct;
        colorMap[key] = c;
      }

      final sortedColors = colorAgg.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final primaryKey = sortedColors.first.key;
      final primaryColor = colorMap[primaryKey]!;
      ColorInfo? secondaryColor;
      if (sortedColors.length > 1) {
        final secondKey = sortedColors[1].key;
        secondaryColor = colorMap[secondKey];
      }

      // Build colors list with percentages. Make any accent color optional by
      // normalizing actual prominence from the outfit and ensuring the
      // accent (secondary) receives a small preference rather than being
      // mandatory. This allows backend to return pieces that are neutral,
      // neutral with a touch of accent, or fully accent-colored.
      final colorsList = <Map<String, dynamic>>[];
      final totalAgg = colorAgg.values.fold<int>(0, (s, v) => s + v);
      int primaryPct = 100;
      int? secondaryPct;
      if (secondaryColor != null && totalAgg > 0) {
        final secondaryAgg =
            colorAgg["${secondaryColor.r},${secondaryColor.g},${secondaryColor.b}"] ??
            0;
        // compute normalized percents, but ensure secondary gets at least 5%
        final rawSecondary = (secondaryAgg / totalAgg) * 100.0;
        final intRawSecondary = rawSecondary.round();
        secondaryPct = intRawSecondary.clamp(
          5,
          50,
        ); // accent is optional small preference
        primaryPct = (100 - secondaryPct).clamp(50, 95);
        colorsList.add({
          'r': primaryColor.r,
          'g': primaryColor.g,
          'b': primaryColor.b,
          'pct': primaryPct,
        });
        colorsList.add({
          'r': secondaryColor.r,
          'g': secondaryColor.g,
          'b': secondaryColor.b,
          'pct': secondaryPct,
        });
      } else {
        colorsList.add({
          'r': primaryColor.r,
          'g': primaryColor.g,
          'b': primaryColor.b,
          'pct': primaryPct,
        });
      }

      final targetColor = primaryColor;

      final specificType = "_unknown";

      List<Map<String, dynamic>> remoteItems = [];

      try {
        final Map<String, dynamic> criteria = {'missingType': missingType};

        criteria['colors'] = colorsList;

        final itemsArray = allClothes
            .where((c) => c.type.toLowerCase() == missingType.toLowerCase())
            .map(
              (item) => {
                'brand': item.brand,
                'product': item.productName,
                'type': item.type,
              },
            )
            .toList();

        criteria['User_${missingType.toLowerCase()}s'] = json.encode(
          itemsArray,
        );

        final colorKey = '${targetColor.r},${targetColor.g},${targetColor.b}';
        final cacheKey =
            '${userStyle.styleType}|${missingType.toLowerCase()}|$colorKey';

        if (_remoteRecommendationCache.containsKey(cacheKey)) {
          remoteItems = _remoteRecommendationCache[cacheKey]!;
        } else {
          remoteItems = await NetworkManager().recommendClothingItems(
            userStyle.styleType,
            criteria,
          );
          _remoteRecommendationCache[cacheKey] = remoteItems;
        }
      } catch (e) {
        remoteItems = [];
      }

      List<String> suggestedBrands = [];
      String reason = 'Recommended based on your style';
      double potentialScore = min(
        98.0,
        currentScore + 15 + random.nextDouble() * 10,
      );

      if (remoteItems.isNotEmpty) {
        final first = remoteItems.first;
        if (first['colors'] != null) {
          final colorField = first['colors'] as String;
          final firstColor = colorField.split(';').first.trim();
          final vals = firstColor
              .split(',')
              .map((s) => int.tryParse(s.trim()) ?? 0)
              .toList();
          if (vals.length >= 3) {
            final remoteColor = ColorInfo(
              r: vals[0],
              g: vals[1],
              b: vals[2],
              pct: 100,
            );
            final colorsForKeywords = <ColorInfo>[remoteColor];
            if (secondaryColor != null) colorsForKeywords.add(secondaryColor);
            Map<String, dynamic>? googleResultForFirst;
            try {
              final searchPayloadFirst = {
                'product':
                    first['product'] ?? first['specificType'] ?? missingType,
                'brand': (first['brand'] is String)
                    ? first['brand']
                    : (first['brand'] is List && first['brand'].isNotEmpty)
                    ? first['brand'][0]
                    : '',
                'colors': colorsForKeywords
                    .map((c) => {'r': c.r, 'g': c.g, 'b': c.b})
                    .toList(),
              };
              googleResultForFirst = await NetworkManager().googleSearch(
                searchPayloadFirst,
              );
            } catch (_) {
              googleResultForFirst = null;
            }

            final recommendation = MissingPieceRecommendation(
              type: missingType,
              product: first['product'] ?? "unknown",
              specificType: first['specificType'] ?? "unknown",
              suggestedBrands: first['brand'] != null
                  ? (first['brand'] is List
                        ? List<String>.from(
                            (first['brand'] as List).map(
                              (e) => e.toString().toLowerCase(),
                            ),
                          )
                        : [(first['brand'] as String).toLowerCase()])
                  : suggestedBrands,
              targetColor: remoteColor,
              existingOutfit: fullOutfit,
              currentScore: currentScore,
              potentialScore: potentialScore,
              reason: first['reason'] ?? reason,
              searchKeywords: [],
              googleName: googleResultForFirst != null
                  ? (googleResultForFirst['Name'])
                  : null,
              googleImageUrl: googleResultForFirst != null
                  ? (googleResultForFirst['ImageURL'])
                  : null,
              googleUrl: googleResultForFirst != null
                  ? (googleResultForFirst['url'])
                  : null,
            );

            final isDuplicate = recommendations.any(
              (r) =>
                  r.type == recommendation.type &&
                  r.targetColor.r == recommendation.targetColor.r &&
                  r.targetColor.g == recommendation.targetColor.g &&
                  r.targetColor.b == recommendation.targetColor.b,
            );

            if (!isDuplicate) recommendations.add(recommendation);
            continue;
          }
        }
        final colorsForKeywords = <ColorInfo>[targetColor];
        if (secondaryColor != null) colorsForKeywords.add(secondaryColor);

        Map<String, dynamic>? googleResult;
        try {
          final searchPayload = {
            'product':
                remoteItems.first['product'] ??
                remoteItems.first['specificType'] ??
                missingType,
            'brand': (remoteItems.first['brand'] is String)
                ? remoteItems.first['brand']
                : (remoteItems.first['brand'] is List &&
                      remoteItems.first['brand'].isNotEmpty)
                    ? remoteItems.first['brand'][0]
                    : '',
            'colors': colorsForKeywords
                .map((c) => {'r': c.r, 'g': c.g, 'b': c.b})
                .toList(),
          };
          googleResult = await NetworkManager().googleSearch(searchPayload);
          print('🔔 googleResult for $missingType -> $googleResult');
          if (googleResult == null) {
            print('🔕 googleResult is null for $missingType');
          } else {
            print('🔎 googleResult keys: ${googleResult.keys.toList()}');
          }
        } catch (e) {
          print('Google search failed for $missingType: $e');
          googleResult = null;
        }

        final recommendation = MissingPieceRecommendation(
          type: missingType,
          product: remoteItems.first['product'] ?? "unknown",
          specificType: remoteItems.first['specificType'] ?? specificType,
          suggestedBrands: remoteItems.first['brand'] != null
              ? (remoteItems.first['brand'] is List
                    ? List<String>.from(
                        (remoteItems.first['brand'] as List).map(
                          (e) => e.toString().toLowerCase(),
                        ),
                      )
                    : [(remoteItems.first['brand'] as String).toLowerCase()])
              : suggestedBrands,
          targetColor: targetColor,
          existingOutfit: fullOutfit,
          currentScore: currentScore,
          potentialScore: potentialScore,
          reason: remoteItems.first['reason'] ?? reason,
          searchKeywords: [],
          googleName: googleResult != null
              ? (googleResult['Name'])
              : remoteItems.first['product'],
          googleImageUrl: googleResult != null
              ? googleResult['ImageURL']
              : null,
          googleUrl: googleResult != null ? googleResult['url'] : null,
        );

        final isDuplicate = recommendations.any(
          (r) =>
              r.type == recommendation.type &&
              r.targetColor.r == recommendation.targetColor.r &&
              r.targetColor.g == recommendation.targetColor.g &&
              r.targetColor.b == recommendation.targetColor.b,
        );

        if (!isDuplicate) recommendations.add(recommendation);
        continue;
      }
    }
    return recommendations;
  }
}
