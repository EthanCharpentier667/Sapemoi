import 'dart:convert';
import 'dart:io';

import '../auth_manager.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../db_manager.dart';
import '../outfit_generator.dart';

class OutfitGeneratorPage extends StatefulWidget {
  final List<Clothing> clothes;
  final VoidCallback onUpdate;

  const OutfitGeneratorPage({super.key, required this.clothes, required this.onUpdate});

  @override
  State<OutfitGeneratorPage> createState() => _OutfitGeneratorPageState();
}

class _OutfitGeneratorPageState extends State<OutfitGeneratorPage> {
  Map<String, bool> selectedTypes = {};
  List<OutfitWithResult> results = [];
  bool boldMode = false;
  bool debugShowAll = false;

  @override
  void initState() {
    super.initState();
    _updateAvailableTypes();
  }

  void _updateAvailableTypes() {
    final types = <String>{};
    for (final item in widget.clothes) {
      types.add(item.type);
    }

    for (final type in types) {
      final isHeadwear = type.toLowerCase() == 'headwear';
      final isMandatory = ['top', 'bottom', 'footwear'].contains(type.toLowerCase());

      if (isMandatory) {
        selectedTypes[type] = true;
      } else {
        selectedTypes.putIfAbsent(type, () => !isHeadwear);
      }
    }

    selectedTypes.removeWhere((key, value) => !types.contains(key));
  }

  @override
  void didUpdateWidget(covariant OutfitGeneratorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clothes != widget.clothes) _updateAvailableTypes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outfits'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What do you want to wear?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (selectedTypes.isEmpty)
                  const Text('Add some clothes to generate outfits!')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedTypes.keys.map((type) {
                      final isMandatory = ['top', 'bottom', 'footwear'].contains(type.toLowerCase());
                      final isSelected = selectedTypes[type]!;

                      return FilterChip(
                        label: Text(type),
                        selected: isSelected,
                        onSelected: isMandatory ? null : (value) {
                          setState(() => selectedTypes[type] = value);
                        },
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Bold Mode'),
                    const Spacer(),
                    Switch(
                      value: boldMode,
                      onChanged: (value) => setState(() => boldMode = value),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Debug: Show All'),
                    const Spacer(),
                    Switch(
                      value: debugShowAll,
                      onChanged: (value) => setState(() => debugShowAll = value),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: selectedTypes.values.any((v) => v) ? _generateOutfits : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Generate Outfits'),
                ),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const Center(child: Text('No outfits generated yet'))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.65,
                    ),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final outfit = results[index];
                      final compatibility = (100 - outfit.result.score).toInt();

                      return GestureDetector(
                        onTap: () async {
                          final shouldMark = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Mark as Worn?'),
                              content: const Text('Do you want to mark this outfit as used? This will help diversify future suggestions.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Mark as Worn'),
                                ),
                              ],
                            ),
                          );

                          if (shouldMark == true && mounted) {
                            final userModel = await AuthManager().getLocalUser();
                            if (userModel != null) {
                              final ids = outfit.outfit.map((c) => c.id).toList();
                              await DBManager().markOutfitAsUsed(ids, userModel.uid);
                              widget.onUpdate();

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Outfit marked as worn!')),
                                );
                              }
                            }
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final itemCount = outfit.outfit.length;
                                          final crossAxisCount = itemCount <= 2 ? itemCount : (itemCount <= 4 ? 2 : 3);

                                          return GridView.builder(
                                            physics: const NeverScrollableScrollPhysics(),
                                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: crossAxisCount,
                                              crossAxisSpacing: 1,
                                              mainAxisSpacing: 1,
                                            ),
                                            itemCount: itemCount,
                                            itemBuilder: (context, i) {
                                              final item = outfit.outfit[i];
                                              return Container(
                                                color: Colors.grey[100],
                                                child: item.imageBase64 != null
                                                    ? Image.memory(
                                                        base64Decode(item.imageBase64!),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Image.file(
                                                        File(item.imagePath),
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stack) {
                                                          return const Icon(Icons.broken_image, size: 32);
                                                        },
                                                      ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                '${compatibility}%',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getRatingColor(compatibility),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${outfit.outfit.length} pieces',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (OutfitGenerator.countRecentlyWorn(outfit.outfit) > 0)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.warning_amber,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${OutfitGenerator.countRecentlyWorn(outfit.outfit)} portée(s) cette semaine',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _generateOutfits() {
    final activeTypes = selectedTypes.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toSet();

    if (activeTypes.isEmpty) return;

    final hasTop = activeTypes.any((t) => t.toLowerCase() == 'top');
    final hasBottom = activeTypes.any((t) => t.toLowerCase() == 'bottom');
    final hasDress = activeTypes.any((t) => t.toLowerCase() == 'dress');

    if (!hasTop && !hasBottom && !hasDress) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least a top, bottom, or dress')));
      return;
    }

    final allByType = <String, List<Clothing>>{};
    for (final item in widget.clothes) {
      if (activeTypes.contains(item.type)) {
        allByType.putIfAbsent(item.type, () => []).add(item);
      }
    }

    for (final type in allByType.keys) {
      allByType[type]!.sort((a, b) => a.wearCount.compareTo(b.wearCount));
    }

    final found = <OutfitWithResult>[];
    final seenCombos = <String>{};

    int maxWearCount = 0;
    while (found.length < 10 && maxWearCount <= 50) {
      final byType = <String, List<Clothing>>{};

      for (final type in allByType.keys) {
        final filtered = allByType[type]!.where((item) => item.wearCount <= maxWearCount).toList();
        if (filtered.isNotEmpty) {
          byType[type] = filtered.length > 8 ? filtered.take(8).toList() : filtered;
        }
      }

      if (byType.isEmpty) break;

      final previousCount = found.length;
      _generateSmartOutfits(byType, activeTypes.toList(), found, seenCombos, maxOutfits: 10);

      if (found.length == previousCount) {
        maxWearCount++;
      } else if (found.length >= 10) {
        break;
      } else {
        maxWearCount++;
      }
    }

    found.sort((a, b) {
      final totalWearCountA = a.outfit.fold<int>(0, (sum, item) => sum + item.wearCount);
      final totalWearCountB = b.outfit.fold<int>(0, (sum, item) => sum + item.wearCount);
      final wearCompare = totalWearCountA.compareTo(totalWearCountB);
      if (wearCompare != 0) return wearCompare;

      return a.result.score.compareTo(b.result.score);
    });

    setState(() => results = found.take(10).toList());
  }

  void _generateSmartOutfits(
    Map<String, List<Clothing>> byType,
    List<String> types,
    List<OutfitWithResult> results,
    Set<String> seenCombos,
    {int maxOutfits = 50}
  ) {
    var attempts = 0;
    final maxAttempts = 500;
    final itemUsageCount = <int, int>{};
    final typeRotationIndex = <String, int>{};

    for (final type in types) {
      typeRotationIndex[type] = 0;
    }

    while (results.length < maxOutfits && attempts < maxAttempts) {
      attempts++;

      final outfit = <Clothing>[];
      var skipOutfit = false;

      for (final type in types) {
        if (!byType.containsKey(type) || byType[type]!.isEmpty) {
          skipOutfit = true;
          break;
        }

        final items = byType[type]!;
        var selectedItem = items[typeRotationIndex[type]! % items.length];

        final isFootwear = type.toLowerCase() == 'footwear';
        final currentUsage = itemUsageCount[selectedItem.id] ?? 0;

        if (!isFootwear && currentUsage >= 3) {
          var foundAlternative = false;
          for (var offset = 1; offset < items.length; offset++) {
            final altIndex = (typeRotationIndex[type]! + offset) % items.length;
            final altItem = items[altIndex];
            final altUsage = itemUsageCount[altItem.id] ?? 0;

            if (altUsage < 3) {
              selectedItem = altItem;
              foundAlternative = true;
              break;
            }
          }

          if (!foundAlternative) {
            skipOutfit = true;
            break;
          }
        }

        outfit.add(selectedItem);
        typeRotationIndex[type] = (typeRotationIndex[type]! + 1) % items.length;
      }

      if (skipOutfit || outfit.isEmpty || outfit.length != types.length) {
        continue;
      }

      final comboKey = outfit.map((c) => c.id).toList()..sort();
      final key = comboKey.join('-');

      if (seenCombos.contains(key)) continue;
      seenCombos.add(key);

      final result = OutfitGenerator.evaluateOutfitWithWeights(outfit, boldMode: boldMode);

      if (debugShowAll || result.score <= 50) {
        for (final item in outfit) {
          itemUsageCount[item.id] = (itemUsageCount[item.id] ?? 0) + 1;
        }
        final recency = OutfitGenerator.getRecencyWeight(outfit);
        results.add(OutfitWithResult(outfit: outfit, result: result, recencyWeight: recency));
      }
    }
  }

  MaterialColor _getRatingColor(int compatibility) {
    if (compatibility >= 85) return Colors.purple;
    if (compatibility >= 70) return Colors.green;
    if (compatibility >= 55) return Colors.blue;
    if (compatibility >= 40) return Colors.orange;
    return Colors.red;
  }
}

class OutfitWithResult {
  final List<Clothing> outfit;
  final OutfitResult result;
  final double recencyWeight;

  OutfitWithResult({required this.outfit, required this.result, required this.recencyWeight});
}
