import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models.dart';
import '../outfit_generator.dart';
import '../theme.dart';
import '../widgets/outfit_preview_sheet.dart';

class OutfitGeneratorPage extends StatefulWidget {
  final List<Clothing> clothes;
  final VoidCallback onUpdate;

  const OutfitGeneratorPage({
    super.key,
    required this.clothes,
    required this.onUpdate,
  });

  @override
  State<OutfitGeneratorPage> createState() => _OutfitGeneratorPageState();
}

class _OutfitGeneratorPageState extends State<OutfitGeneratorPage> {
  Map<String, bool> selectedTypes = {};
  List<OutfitWithResult> results = [];
  bool boldMode = false;
  bool debugShowAll = false;
  bool _isGenerating = false;

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

    final mandatoryTypes = ['top', 'bottom', 'footwear'];
    
    for (final type in types) {
      final isHeadwear = type.toLowerCase() == 'headwear';
      final isMandatory = mandatoryTypes.contains(type.toLowerCase());

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

  Color _getRatingColor(int compatibility) {
    if (compatibility >= 85) return SapemoiTheme.primary;
    if (compatibility >= 70) return SapemoiTheme.primaryLight;
    if (compatibility >= 55) return SapemoiTheme.primaryMuted;
    if (compatibility >= 40) return SapemoiTheme.textSecondary;
    return SapemoiTheme.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SapemoiTheme.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),
          
          // Type Selection
          SliverToBoxAdapter(
            child: _buildTypeSelection(),
          ),
          
          // Options
          SliverToBoxAdapter(
            child: _buildOptions(),
          ),
          
          // Generate Button
          SliverToBoxAdapter(
            child: _buildGenerateButton(),
          ),
          
          // Results Grid
          if (results.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.65,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildOutfitCard(results[index]),
                  childCount: results.length,
                ),
              ),
            ),
          
          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 8,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: SapemoiTheme.primaryGradient,
              borderRadius: BorderRadius.circular(SapemoiTheme.radiusSm),
              boxShadow: [SapemoiTheme.shadowGlow(SapemoiTheme.primary)],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Outfits',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: SapemoiTheme.textPrimary,
                  ),
                ),
                Text(
                  'AI-powered outfit suggestions',
                  style: TextStyle(
                    fontSize: 13,
                    color: SapemoiTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelection() {
    if (selectedTypes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: SapemoiTheme.surface,
            borderRadius: BorderRadius.circular(SapemoiTheme.radiusLg),
            border: Border.all(color: SapemoiTheme.border),
          ),
          child: Column(
            children: [
              Icon(Icons.add_circle_outline, size: 48, color: SapemoiTheme.textMuted),
              const SizedBox(height: 12),
              Text(
                'Add some clothes first!',
                style: TextStyle(
                  color: SapemoiTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What do you want to wear?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: SapemoiTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: selectedTypes.keys.map((type) {
              final mandatoryTypes = ['top', 'bottom', 'footwear'];
              final isMandatory = mandatoryTypes.contains(type.toLowerCase());
              final isSelected = selectedTypes[type]!;

              return GestureDetector(
                onTap: isMandatory ? null : () {
                  setState(() => selectedTypes[type] = !isSelected);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected ? SapemoiTheme.primaryGradient : null,
                    color: isSelected ? null : SapemoiTheme.surface,
                    borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
                    border: Border.all(
                      color: isSelected 
                        ? Colors.transparent 
                        : SapemoiTheme.border,
                    ),
                    boxShadow: isSelected
                      ? [SapemoiTheme.shadowGlow(SapemoiTheme.primary)]
                      : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isMandatory)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.lock,
                            size: 12,
                            color: isSelected ? Colors.white70 : SapemoiTheme.textMuted,
                          ),
                        ),
                      Text(
                        _capitalizeFirst(type),
                        style: TextStyle(
                          color: isSelected ? Colors.white : SapemoiTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SapemoiTheme.surface,
          borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
          border: Border.all(color: SapemoiTheme.border),
        ),
        child: Column(
          children: [
            _buildOptionRow(
              icon: Icons.bolt,
              title: 'Bold Mode',
              subtitle: 'More adventurous combinations',
              value: boldMode,
              onChanged: (value) => setState(() => boldMode = value),
              color: SapemoiTheme.accent,
            ),
            Divider(color: SapemoiTheme.border, height: 24),
            _buildOptionRow(
              icon: Icons.bug_report,
              title: 'Debug Mode',
              subtitle: 'Show all generated outfits',
              value: debugShowAll,
              onChanged: (value) => setState(() => debugShowAll = value),
              color: SapemoiTheme.primaryMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(SapemoiTheme.radiusSm),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: SapemoiTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: SapemoiTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: color,
          activeTrackColor: color.withOpacity(0.3),
          inactiveThumbColor: SapemoiTheme.textMuted,
          inactiveTrackColor: SapemoiTheme.surfaceLight,
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    final canGenerate = selectedTypes.values.any((v) => v);
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GestureDetector(
        onTap: canGenerate && !_isGenerating ? _generateOutfits : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: canGenerate ? SapemoiTheme.primaryGradient : null,
            color: canGenerate ? null : SapemoiTheme.surfaceLight,
            borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
            boxShadow: canGenerate
              ? [SapemoiTheme.shadowGlow(SapemoiTheme.primary)]
              : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isGenerating)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  Icons.auto_awesome,
                  color: canGenerate ? Colors.white : SapemoiTheme.textMuted,
                  size: 20,
                ),
              const SizedBox(width: 10),
              Text(
                _isGenerating ? 'Generating...' : 'Generate Outfits',
                style: TextStyle(
                  color: canGenerate ? Colors.white : SapemoiTheme.textMuted,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: SapemoiTheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.style_outlined,
              size: 48,
              color: SapemoiTheme.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No outfits generated yet',
            style: TextStyle(
              color: SapemoiTheme.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button above to generate',
            style: TextStyle(
              color: SapemoiTheme.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitCard(OutfitWithResult outfit) {
    final compatibility = (100 - outfit.result.score).toInt();
    final recentlyWornCount = OutfitGenerator.countRecentlyWorn(outfit.outfit);

    return GestureDetector(
      onTap: () async {
        await OutfitPreviewSheet.show(
          context,
          items: outfit.outfit,
          score: outfit.result,
          onWorn: widget.onUpdate,
          title: 'Generated Outfit',
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: SapemoiTheme.surface,
          borderRadius: BorderRadius.circular(SapemoiTheme.radiusLg),
          border: Border.all(color: SapemoiTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Images Grid
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(SapemoiTheme.radiusLg - 1),
                    ),
                    child: _buildOutfitGrid(outfit.outfit),
                  ),
                  // Recently worn badge
                  if (recentlyWornCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: SapemoiTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
                          border: Border.all(color: SapemoiTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.history, color: SapemoiTheme.textSecondary, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '$recentlyWornCount worn',
                              style: const TextStyle(
                                color: SapemoiTheme.textSecondary,
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
            ),
            
            // Score section
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getRatingColor(compatibility).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
                      ),
                      child: Text(
                        '$compatibility%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _getRatingColor(compatibility),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${outfit.outfit.length} pieces',
                      style: TextStyle(
                        fontSize: 12,
                        color: SapemoiTheme.textMuted,
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
    );
  }

  Widget _buildOutfitGrid(List<Clothing> outfit) {
    final itemCount = outfit.length;
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
        final item = outfit[i];
        return Container(
          color: SapemoiTheme.surfaceLight,
          child: CachedNetworkImage(
            imageUrl: item.imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: SapemoiTheme.surfaceLight,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SapemoiTheme.primary,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: SapemoiTheme.surfaceLight,
              child: Icon(Icons.checkroom, color: SapemoiTheme.textMuted),
            ),
          ),
        );
      },
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  void _generateOutfits() {
    setState(() => _isGenerating = true);

    final activeTypes = selectedTypes.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toSet();

    if (activeTypes.isEmpty) {
      setState(() => _isGenerating = false);
      return;
    }

    final hasTop = activeTypes.any((t) => t.toLowerCase() == 'top');
    final hasBottom = activeTypes.any((t) => t.toLowerCase() == 'bottom');
    final hasFootwear = activeTypes.any((t) => t.toLowerCase() == 'footwear');

    if (!hasTop || !hasBottom || !hasFootwear) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('You need at least a top, bottom, and footwear'),
            backgroundColor: SapemoiTheme.surface,
          ),
        );
      }
      setState(() => _isGenerating = false);
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

      if (byType.isEmpty) {
        maxWearCount++;
        continue;
      }

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

    setState(() {
      results = found.take(10).toList();
      _isGenerating = false;
    });
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
}

class OutfitWithResult {
  final List<Clothing> outfit;
  final OutfitResult result;
  final double recencyWeight;

  OutfitWithResult({required this.outfit, required this.result, required this.recencyWeight});
}
