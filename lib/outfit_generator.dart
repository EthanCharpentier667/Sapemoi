import 'models.dart';
import 'color_utils.dart';

class OutfitGenerator {
  static bool _areLayersAdjacent(int layer1, int layer2) {
    return (layer1 - layer2).abs() == 1;
  }

  static double _hueDifference(double h1, double h2) {
    var diff = (h1 - h2).abs();
    if (diff > 180) diff = 360 - diff;
    return diff;
  }

  static ({int count, Set<String> pairs}) _detectColorRecalls(
    Map<int, List<({int index, Set<double> hues})>> itemsByLayer,
    List<Clothing> outfit,
  ) {
    var colorRecallCount = 0;
    final recalledPairs = <String>{};
    final pairsWithRecall = <String>{};

    final allItems = itemsByLayer.values.expand((items) => items).toList();

    for (var i = 0; i < allItems.length - 1; i++) {
      for (var j = i + 1; j < allItems.length; j++) {
        final item1 = allItems[i];
        final item2 = allItems[j];
        
        final layer1 = outfit[item1.index].layer;
        final layer2 = outfit[item2.index].layer;

        for (final h1 in item1.hues) {
          for (final h2 in item2.hues) {
            final diff = _hueDifference(h1, h2);
            
            if (diff < 20) {
              if (!_areLayersAdjacent(layer1, layer2)) {
                final key = '${item1.index}_${item2.index}';
                if (!recalledPairs.contains(key)) {
                  colorRecallCount++;
                  recalledPairs.add(key);
                  pairsWithRecall.add(key);
                }
              }
            }
          }
        }
      }
    }

    return (count: colorRecallCount, pairs: pairsWithRecall);
  }

  static ({
    List<(double, double, double)> vibrantColors,
    Map<int, List<({int index, Set<double> hues})>> itemsByLayer,
    int neutralCount,
  }) _analyzeOutfitColors(List<Clothing> outfit) {
    final vibrantColors = <(double, double, double)>[];
    final itemsByLayer = <int, List<({int index, Set<double> hues})>>{};
    var neutralCount = 0;
    
    for (var i = 0; i < outfit.length; i++) {
      final item = outfit[i];
      final itemHues = <double>{};
      var hasNeutralDominant = false;
      
      for (final color in item.colors) {
        final r = color.r / 255.0;
        final g = color.g / 255.0;
        final b = color.b / 255.0;
        
        if (isNeutral(r, g, b) && color.pct > 50) {
          hasNeutralDominant = true;
        }
        
        if (!isNeutral(r, g, b) && color.pct >= 30) {
          vibrantColors.add((r, g, b));
          final hsl = rgbToHsl(r, g, b);
          itemHues.add(hsl.h);
        }
      }
      
      if (hasNeutralDominant) {
        neutralCount++;
      }
      
      if (itemHues.isNotEmpty) {
        itemsByLayer
            .putIfAbsent(item.layer, () => [])
            .add((index: i, hues: itemHues));
      }
    }

    return (
      vibrantColors: vibrantColors,
      itemsByLayer: itemsByLayer,
      neutralCount: neutralCount,
    );
  }

  static double _evaluateNeutralColors(int neutralCount, int outfitLength, int totalColoredItems) {
    var score = 0.0;
    
    if (neutralCount == outfitLength && outfitLength >= 3) {
      score -= 20;
    }
    
    if (neutralCount >= outfitLength - 1 && outfitLength >= 3 && totalColoredItems == 1 && neutralCount < outfitLength) {
      score += 15;
    }
    
    return score;
  }

  static double _evaluateAdjacentLayers(
    Map<int, List<({int index, Set<double> hues})>> itemsByLayer,
    List<Clothing> outfit,
  ) {
    var score = 0.0;
    
    final sortedLayers = itemsByLayer.keys.toList()..sort();
    
    for (var i = 0; i < sortedLayers.length - 1; i++) {
      final currentLayer = sortedLayers[i];
      final nextLayer = sortedLayers[i + 1];
      
      if (nextLayer - currentLayer == 1) {
        final currentItems = itemsByLayer[currentLayer]!;
        final nextItems = itemsByLayer[nextLayer]!;
        
        for (final item1 in currentItems) {
          for (final item2 in nextItems) {
            final isMonochrome1 = item1.hues.length == 1;
            final isMonochrome2 = item2.hues.length == 1;
            
            if (isMonochrome1 && isMonochrome2) {
              final h1 = item1.hues.first;
              final h2 = item2.hues.first;
              final diff = _hueDifference(h1, h2);
              
              if (diff < 30) {
                score += 45;
              }
            } else if (!isMonochrome1 || !isMonochrome2) {
              var hasSubtleRecall = false;
              
              final clothing1 = outfit[item1.index];
              final clothing2 = outfit[item2.index];
              
              for (final c1 in clothing1.colors) {
                if (isNeutral(c1.r / 255.0, c1.g / 255.0, c1.b / 255.0)) continue;
                final hsl1 = rgbToHsl(c1.r / 255.0, c1.g / 255.0, c1.b / 255.0);
                
                for (final c2 in clothing2.colors) {
                  if (isNeutral(c2.r / 255.0, c2.g / 255.0, c2.b / 255.0)) continue;
                  final hsl2 = rgbToHsl(c2.r / 255.0, c2.g / 255.0, c2.b / 255.0);
                  
                  final diff = _hueDifference(hsl1.h, hsl2.h);
                  
                  if (diff < 30) {
                    if ((c1.pct < 40 && c2.pct > 50) || (c2.pct < 40 && c1.pct > 50)) {
                      hasSubtleRecall = true;
                      break;
                    }
                  }
                }
                if (hasSubtleRecall) break;
              }
              
              if (hasSubtleRecall) {
                score -= 25;
              }
            }
          }
        }
      }
    }
    
    return score;
  }

  static double _evaluateColorDominance(Map<int, List<({int index, Set<double> hues})>> itemsByLayer) {
    final totalColoredItems = itemsByLayer.values.fold(0, (sum, items) => sum + items.length);
    
    if (totalColoredItems < 3) return 0.0;
    
    final allHues = <double>[];
    for (final items in itemsByLayer.values) {
      for (final item in items) {
        allHues.addAll(item.hues);
      }
    }
    
    for (final targetHue in allHues) {
      var matchCount = 0;
      for (final items in itemsByLayer.values) {
        for (final item in items) {
          for (final h in item.hues) {
            final diff = _hueDifference(targetHue, h);
            if (diff < 30) {
              matchCount++;
              break;
            }
          }
        }
      }
      if (matchCount >= 3) {
        return 50.0;
      }
    }
    
    return 0.0;
  }

  static ({double score, List<ColorClash> clashes}) _evaluateColorClashes(
    List<Clothing> outfit,
    Set<String> pairsWithRecall,
    bool boldMode,
  ) {
    final maxSimple = 60.0;
    final maxBold = 100.0;
    final max = boldMode ? maxBold : maxSimple;
    final clashes = <ColorClash>[];
    var totalScore = 0.0;

    for (var i = 0; i < outfit.length; i++) {
      for (var j = i + 1; j < outfit.length; j++) {
        final pairKey = '${i}_$j';
        if (pairsWithRecall.contains(pairKey)) {
          continue;
        }
        
        final a = outfit[i];
        final b = outfit[j];
        
        for (final cr1 in a.colors) {
          for (final cr2 in b.colors) {
            final r1 = cr1.r / 255.0;
            final g1 = cr1.g / 255.0;
            final b1 = cr1.b / 255.0;

            final r2 = cr2.r / 255.0;
            final g2 = cr2.g / 255.0;
            final b2 = cr2.b / 255.0;

            final isNeutral1 = isNeutral(r1, g1, b1);
            final isNeutral2 = isNeutral(r2, g2, b2);
            
            if (isNeutral1 || isNeutral2) {
              continue;
            }

            final sc = colorPairScore(
              c1: (r1, g1, b1),
              c2: (r2, g2, b2),
              p1: cr1.pct / 100.0,
              p2: cr2.pct / 100.0,
            );

            double visibilityWeight = 1.0;
            
            final layerDiff = (a.layer - b.layer).abs();
            if (layerDiff == 0) {
              visibilityWeight *= 0.5;
            } else if (layerDiff == 1) {
              visibilityWeight *= 3.0;
            } else if (layerDiff == 2) {
              visibilityWeight *= 5.0;
            } else {
              visibilityWeight *= 2.0;
            }

            final typeA = a.specificType.toLowerCase();
            final typeB = b.specificType.toLowerCase();
            
            if (typeA.contains('coat') || typeA.contains('manteau') || typeA.contains('jacket')) {
              visibilityWeight *= 2.0;
            }
            if (typeB.contains('coat') || typeB.contains('manteau') || typeB.contains('jacket')) {
              visibilityWeight *= 2.0;
            }

            final weightedScore = sc * visibilityWeight;
            totalScore += weightedScore;

            if (weightedScore > max) {
              clashes.add(ColorClash(
                type1: a.type,
                color1: cr1,
                type2: b.type,
                color2: cr2,
                score: weightedScore,
              ));
            }
          }
        }
      }
    }

    return (score: totalScore, clashes: clashes);
  }
  
  static OutfitResult evaluateOutfitWithWeights(List<Clothing> outfit, {required bool boldMode}) {
    final baseResult = evaluateOutfit(outfit, boldMode: boldMode);
    return baseResult;
  }
  
  static int countRecentlyWorn(List<Clothing> outfit) {
    final now = DateTime.now();
    var count = 0;
    
    for (final item in outfit) {
      if (item.lastWorn != null) {
        final daysSinceWorn = now.difference(item.lastWorn!).inDays;
        if (daysSinceWorn < 7) {
          count++;
        }
      }
    }
    
    return count;
  }
  
  static double getRecencyWeight(List<Clothing> outfit) {
    final now = DateTime.now();
    var totalPenalty = 0.0;
    
    for (final item in outfit) {
      if (item.lastWorn != null) {
        final daysSinceWorn = now.difference(item.lastWorn!).inDays;
        
        if (daysSinceWorn < 7) {
          totalPenalty += 15.0;
        } else if (daysSinceWorn < 14) {
          totalPenalty += 8.0;
        } else if (daysSinceWorn < 30) {
          totalPenalty += 3.0;
        }
      }
    }
    
    return totalPenalty;
  }

  static bool hasConflictingTypes(List<Clothing> outfit) {
    final layerTypeMap = <int, Set<String>>{};
    
    for (final item in outfit) {
      final layer = item.layer;
      final type = item.type.toLowerCase();
      
      if (!layerTypeMap.containsKey(layer)) {
        layerTypeMap[layer] = {};
      }
      
      if (layerTypeMap[layer]!.contains(type)) {
        return true;
      }
      
      layerTypeMap[layer]!.add(type);
    }
    
    return false;
  }

  static OutfitResult evaluateOutfit(List<Clothing> outfit, {required bool boldMode}) {
    if (hasConflictingTypes(outfit)) {
      return OutfitResult(
        valid: false, 
        score: 100, 
        clashes: [
          ColorClash(
            type1: 'outfit',
            color1: ColorInfo(r: 0, g: 0, b: 0, pct: 0),
            type2: 'conflict',
            color2: ColorInfo(r: 0, g: 0, b: 0, pct: 0),
            score: 999,
          )
        ],
      );
    }

    var totalScore = 0.0;
    
    final colorAnalysis = _analyzeOutfitColors(outfit);
    
    totalScore += _evaluateNeutralColors(
      colorAnalysis.neutralCount,
      outfit.length,
      colorAnalysis.itemsByLayer.values.fold(0, (sum, items) => sum + items.length),
    );
    
    if (colorAnalysis.vibrantColors.length > 3) {
      final penalty = (colorAnalysis.vibrantColors.length - 3) * 25;
      totalScore += penalty;
    }
    
    final recallResult = _detectColorRecalls(
      colorAnalysis.itemsByLayer,
      outfit,
    );
    
    if (recallResult.count > 0) {
      final bonus = recallResult.count * 50;
      totalScore -= bonus;
    }
    
    totalScore += _evaluateAdjacentLayers(
      colorAnalysis.itemsByLayer,
      outfit,
    );
    
    totalScore += _evaluateColorDominance(colorAnalysis.itemsByLayer);

    final clashResult = _evaluateColorClashes(
      outfit,
      recallResult.pairs,
      boldMode,
    );
    
    totalScore += clashResult.score;

    totalScore = totalScore.clamp(0, 100.0);
    final valid = clashResult.clashes.isEmpty && totalScore < 40;
    
    return OutfitResult(valid: valid, score: totalScore, clashes: clashResult.clashes);
  }
}
