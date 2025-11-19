import 'models.dart';
import 'color_utils.dart';

class OutfitGenerator {
  static final Map<String, Set<String>> conflictingTypes = {
    'headwear': {'headwear'},
    'dress': {'top', 'bottom', 'dress'},
    'top': {'dress'},
    'bottom': {'dress'},
    'footwear': {'footwear'},
  };
  
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
    final types = outfit.map((c) => c.type.toLowerCase()).toList();
    
    for (var i = 0; i < types.length; i++) {
      final type1 = types[i];
      
      final conflicts = conflictingTypes[type1];
      if (conflicts != null) {
        for (var j = i + 1; j < types.length; j++) {
          final type2 = types[j];
          if (conflicts.contains(type2)) {
            return true;
          }
        }
      }
      
      if (type1 != 'underwear' && type1 != 'accessory') {
        for (var j = i + 1; j < types.length; j++) {
          if (types[j] == type1) {
            return true;
          }
        }
      }
    }
    
    return false;
  }

  static OutfitResult evaluateOutfit(List<Clothing> outfit, {required bool boldMode}) {
    if (hasConflictingTypes(outfit)) {
      return OutfitResult(
        valid: false, 
        score: 0, 
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

    final maxSimple = 60.0;
    final maxBold = 100.0;
    final max = boldMode ? maxBold : maxSimple;

    final clashes = <ColorClash>[];
    var totalScore = 0.0;
    
    final vibrantColors = <(double, double, double)>[];
    final itemHueRanges = <Set<double>>[];
    final itemTypes = <String>[];
    var neutralCount = 0;
    
    for (final item in outfit) {
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
        itemHueRanges.add(itemHues);
        itemTypes.add(item.type.toLowerCase());
      }
    }
    
    if (neutralCount == outfit.length && outfit.length >= 3) {
      totalScore -= 20;
    }
    
    if (neutralCount >= outfit.length - 1 && outfit.length >= 3 && itemHueRanges.length == 1 && neutralCount < outfit.length) {
      totalScore += 15;
    }
    
    if (vibrantColors.length > 3) {
      final penalty = (vibrantColors.length - 3) * 25;
      totalScore += penalty;
    }
    
    var colorRecallCount = 0;
    final recalledPairs = <String>{};
    final pairsWithRecall = <String>{};
    
    for (var i = 0; i < itemHueRanges.length - 1; i++) {
      for (var j = i + 1; j < itemHueRanges.length; j++) {
        for (final h1 in itemHueRanges[i]) {
          for (final h2 in itemHueRanges[j]) {
            var diff = (h1 - h2).abs();
            if (diff > 180) diff = 360 - diff;
            
            if (diff < 20) {
              final type1 = itemTypes[i];
              final type2 = itemTypes[j];
              
              final isAdjacent = 
                (type1 == 'headwear' && type2 == 'outerwear') ||
                (type2 == 'headwear' && type1 == 'outerwear') ||
                (type1 == 'headwear' && type2 == 'top') ||
                (type2 == 'headwear' && type1 == 'top') ||
                (type1 == 'top' && type2 == 'bottom') ||
                (type2 == 'top' && type1 == 'bottom');
              
              if (!isAdjacent) {
                final key = '${i}_$j';
                if (!recalledPairs.contains(key)) {
                  colorRecallCount++;
                  recalledPairs.add(key);
                  
                  final outfitIdx1 = outfit.indexWhere((item) => item.type.toLowerCase() == type1);
                  final outfitIdx2 = outfit.indexWhere((item) => item.type.toLowerCase() == type2);
                  if (outfitIdx1 >= 0 && outfitIdx2 >= 0) {
                    final pairKey = outfitIdx1 < outfitIdx2 ? '${outfitIdx1}_$outfitIdx2' : '${outfitIdx2}_$outfitIdx1';
                    pairsWithRecall.add(pairKey);
                  }
                }
              }
            }
          }
        }
      }
    }
    
    if (colorRecallCount > 0) {
      final bonus = colorRecallCount * 50;
      totalScore -= bonus;
    }
    
    final adjacentPairs = [
      ['headwear', 'outerwear'],
      ['headwear', 'top'],
      ['top', 'bottom'],
    ];
    
    final itemsByType = <String, List<int>>{};
    for (var i = 0; i < itemHueRanges.length; i++) {
      final type = itemTypes[i];
      itemsByType.putIfAbsent(type, () => []).add(i);
    }
    
    for (final pair in adjacentPairs) {
      final type1Indices = itemsByType[pair[0]] ?? [];
      final type2Indices = itemsByType[pair[1]] ?? [];
      
      for (final idx1 in type1Indices) {
        for (final idx2 in type2Indices) {
          final isMonochrome1 = itemHueRanges[idx1].length == 1;
          final isMonochrome2 = itemHueRanges[idx2].length == 1;
          
          if (isMonochrome1 && isMonochrome2) {
            final h1 = itemHueRanges[idx1].first;
            final h2 = itemHueRanges[idx2].first;
            var diff = (h1 - h2).abs();
            if (diff > 180) diff = 360 - diff;
            
            if (diff < 30) {
              totalScore += 45;
            }
          }
          else if (!isMonochrome1 || !isMonochrome2) {
            var hasSubtleRecall = false;
            
            final item1 = outfit.firstWhere((item) => item.type.toLowerCase() == itemTypes[idx1]);
            final item2 = outfit.firstWhere((item) => item.type.toLowerCase() == itemTypes[idx2]);
            
            for (final c1 in item1.colors) {
              if (isNeutral(c1.r / 255.0, c1.g / 255.0, c1.b / 255.0)) continue;
              final hsl1 = rgbToHsl(c1.r / 255.0, c1.g / 255.0, c1.b / 255.0);
              
              for (final c2 in item2.colors) {
                if (isNeutral(c2.r / 255.0, c2.g / 255.0, c2.b / 255.0)) continue;
                final hsl2 = rgbToHsl(c2.r / 255.0, c2.g / 255.0, c2.b / 255.0);
                
                var diff = (hsl1.h - hsl2.h).abs();
                if (diff > 180) diff = 360 - diff;
                
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
              totalScore -= 25;
            }
          }
        }
      }
    }
    
    if (itemHueRanges.length >= 3) {
      final allHues = <double>[];
      for (final hues in itemHueRanges) {
        allHues.addAll(hues);
      }
      
      for (final targetHue in allHues) {
        var matchCount = 0;
        for (final hues in itemHueRanges) {
          for (final h in hues) {
            var diff = (targetHue - h).abs();
            if (diff > 180) diff = 360 - diff;
            if (diff < 30) {
              matchCount++;
              break;
            }
          }
        }
        if (matchCount >= 3) {
          totalScore += 50;
          break;
        }
      }
    }

    for (var i = 0; i < outfit.length; i++) {
      for (var j = i + 1; j < outfit.length; j++) {
        final pairKey = i < j ? '${i}_$j' : '${j}_$i';
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
            
            final typeA = a.specificType.toLowerCase();
            final typeB = b.specificType.toLowerCase();
            
            if (typeA.contains('coat') || typeA.contains('manteau') || typeA.contains('jacket')) {
              visibilityWeight *= 5.0;
            }
            if (typeB.contains('coat') || typeB.contains('manteau') || typeB.contains('jacket')) {
              visibilityWeight *= 5.0;
            }
            
            if (a.type.toLowerCase() == 'outerwear' && !typeA.contains('coat') && !typeA.contains('manteau')) {
              visibilityWeight *= 3.0;
            }
            if (b.type.toLowerCase() == 'outerwear' && !typeB.contains('coat') && !typeB.contains('manteau')) {
              visibilityWeight *= 3.0;
            }
            
            if (a.type.toLowerCase() == 'bottom' || a.type.toLowerCase() == 'footwear') {
              visibilityWeight *= 2.0;
            }
            if (b.type.toLowerCase() == 'bottom' || b.type.toLowerCase() == 'footwear') {
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

    totalScore = totalScore.clamp(0, 100.0);
    final valid = clashes.isEmpty && totalScore < 40;
    
    return OutfitResult(valid: valid, score: totalScore, clashes: clashes);
  }
}
