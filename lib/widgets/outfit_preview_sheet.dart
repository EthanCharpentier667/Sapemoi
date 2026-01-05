import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models.dart';
import '../db_manager.dart';
import '../auth_manager.dart';
import '../outfit_generator.dart';
import '../theme.dart';
import '../pages/create_post_page.dart';

class OutfitPreviewSheet extends StatefulWidget {
  final List<Clothing> items;
  final OutfitResult? score;
  final VoidCallback? onWorn;
  final bool showWornButton;
  final String? title;

  const OutfitPreviewSheet({
    super.key,
    required this.items,
    this.score,
    this.onWorn,
    this.showWornButton = true,
    this.title,
  });

  /// Affiche le sheet en modal bottom sheet
  static Future<bool?> show(
    BuildContext context, {
    required List<Clothing> items,
    OutfitResult? score,
    VoidCallback? onWorn,
    bool showWornButton = true,
    String? title,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OutfitPreviewSheet(
        items: items,
        score: score,
        onWorn: onWorn,
        showWornButton: showWornButton,
        title: title,
      ),
    );
  }

  @override
  State<OutfitPreviewSheet> createState() => _OutfitPreviewSheetState();
}

class _OutfitPreviewSheetState extends State<OutfitPreviewSheet> {
  bool _isMarking = false;

  // Ordre d'affichage des types (de haut en bas)
  static const _typeOrder = [
    'headwear',
    'accessory',
    'outerwear',
    'sweater',
    'top',
    'bottom',
    'footwear',
  ];

  // Labels pour chaque type
  static const _typeLabels = {
    'headwear': 'Headwear',
    'accessory': 'Accessory',
    'outerwear': 'Outerwear',
    'sweater': 'Sweater',
    'top': 'Top',
    'bottom': 'Bottom',
    'footwear': 'Footwear',
  };

  // Icônes pour chaque type
  static const _typeIcons = {
    'headwear': Icons.sports_baseball,
    'accessory': Icons.watch,
    'outerwear': Icons.checkroom,
    'sweater': Icons.thermostat,
    'top': Icons.dry_cleaning,
    'bottom': Icons.wallet,
    'footwear': Icons.shopping_bag,
  };

  Map<String, List<Clothing>> _groupItemsByType() {
    final grouped = <String, List<Clothing>>{};
    for (final item in widget.items) {
      final type = item.type.toLowerCase();
      grouped.putIfAbsent(type, () => []).add(item);
    }
    return grouped;
  }

  List<String> _getSortedTypes(Map<String, List<Clothing>> grouped) {
    final types = grouped.keys.toList();
    types.sort((a, b) {
      final indexA = _typeOrder.indexOf(a);
      final indexB = _typeOrder.indexOf(b);
      if (indexA == -1 && indexB == -1) return a.compareTo(b);
      if (indexA == -1) return 1;
      if (indexB == -1) return -1;
      return indexA.compareTo(indexB);
    });
    return types;
  }

  Color _getScoreColor(int score) {
    if (score >= 85) return const Color(0xFF22C55E);
    if (score >= 75) return const Color(0xFF84CC16);
    if (score >= 60) return SapemoiTheme.primary;
    if (score >= 45) return const Color(0xFFF97316);
    if (score >= 30) return const Color(0xFFEF4444);
    return const Color(0xFFDC2626);
  }

  String _getScoreLabel(int score) {
    if (score >= 85) return 'Perfect Match!';
    if (score >= 75) return 'Great Combo';
    if (score >= 60) return 'Good Match';
    if (score >= 45) return 'Decent';
    if (score >= 30) return 'Risky';
    return 'Bold Choice';
  }

  Future<void> _markAsWorn() async {
    setState(() => _isMarking = true);
    
    try {
      final userModel = await AuthManager().getLocalUser();
      if (userModel != null) {
        final ids = widget.items.map((c) => c.id).toList();
        await DBManager().markOutfitAsUsed(ids, userModel.uid);
        widget.onWorn?.call();
        
        if (mounted) {
          Navigator.pop(context, true);
          _showPostDialog();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isMarking = false);
      }
    }
  }

  void _showPostDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SapemoiTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SapemoiTheme.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: SapemoiTheme.primaryGradient,
                borderRadius: BorderRadius.circular(SapemoiTheme.radiusSm),
              ),
              child: const Icon(Icons.photo_camera, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Share Your Style?',
                style: TextStyle(
                  fontSize: 18,
                  color: SapemoiTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Want to post this outfit to your feed?\n\nShow off your style and inspire others! 📸✨',
          style: TextStyle(color: SapemoiTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Not Now',
              style: TextStyle(color: SapemoiTheme.textMuted),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreatePostPage(outfitItems: widget.items),
                ),
              );
            },
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Post It'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SapemoiTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SapemoiTheme.radiusSm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupItemsByType();
    final sortedTypes = _getSortedTypes(grouped);
    final compatibility = widget.score != null ? (100 - widget.score!.score).toInt() : null;
    final recentlyWornCount = OutfitGenerator.countRecentlyWorn(widget.items);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: SapemoiTheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SapemoiTheme.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: SapemoiTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header avec score
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title ?? 'Outfit Preview',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: SapemoiTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (compatibility != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: SapemoiTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
                          boxShadow: [SapemoiTheme.shadowGlow(SapemoiTheme.primary)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$compatibility%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              compatibility >= 60 ? Icons.thumb_up : Icons.thumbs_up_down,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (compatibility != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getScoreColor(compatibility).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
                        ),
                        child: Text(
                          _getScoreLabel(compatibility),
                          style: TextStyle(
                            color: _getScoreColor(compatibility),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${widget.items.length} pieces',
                        style: TextStyle(
                          color: SapemoiTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
                if (recentlyWornCount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(SapemoiTheme.radiusSm),
                      border: Border.all(color: const Color(0xFFF97316).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber, color: Color(0xFFF97316), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '$recentlyWornCount item${recentlyWornCount > 1 ? 's' : ''} worn this week',
                          style: const TextStyle(
                            color: Color(0xFFF97316),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          Divider(height: 1, color: SapemoiTheme.border),

          // Liste des items par type
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sortedTypes.length,
              itemBuilder: (context, index) {
                final type = sortedTypes[index];
                final items = grouped[type]!;
                return _buildTypeSection(type, items);
              },
            ),
          ),

          // Boutons d'action
          if (widget.showWornButton)
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: 16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: SapemoiTheme.background,
                border: Border(
                  top: BorderSide(color: SapemoiTheme.border),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: SapemoiTheme.surface,
                          borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
                          border: Border.all(color: SapemoiTheme.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close, color: SapemoiTheme.textSecondary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Close',
                              style: TextStyle(
                                color: SapemoiTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _isMarking ? null : _markAsWorn,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                          ),
                          borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22C55E).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _isMarking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _isMarking ? 'Marking...' : 'Mark as Worn',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeSection(String type, List<Clothing> items) {
    final label = _typeLabels[type] ?? type.capitalize();
    final icon = _typeIcons[type] ?? Icons.checkroom;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SapemoiTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(SapemoiTheme.radiusSm),
                ),
                child: Icon(icon, size: 20, color: SapemoiTheme.textSecondary),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: SapemoiTheme.textSecondary,
                ),
              ),
              if (items.length > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: SapemoiTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
                  ),
                  child: Text(
                    '×${items.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: SapemoiTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          
          // Items grid
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _buildItemCard(items[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Clothing item) {
    final isRecentlyWorn = item.lastWorn != null &&
        DateTime.now().difference(item.lastWorn!).inDays < 7;

    return Container(
      width: 100,
      decoration: BoxDecoration(
        color: SapemoiTheme.surfaceLight,
        borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
        border: Border.all(
          color: isRecentlyWorn 
            ? const Color(0xFFF97316).withOpacity(0.5) 
            : SapemoiTheme.border,
          width: isRecentlyWorn ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(SapemoiTheme.radiusMd - 1),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      color: SapemoiTheme.surface,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: SapemoiTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: SapemoiTheme.surface,
                      child: Icon(Icons.checkroom, color: SapemoiTheme.textMuted),
                    ),
                  ),
                ),
                if (isRecentlyWorn)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316),
                        borderRadius: BorderRadius.circular(SapemoiTheme.radiusXs),
                      ),
                      child: const Icon(
                        Icons.history,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Info
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.brand,
                  style: TextStyle(
                    fontSize: 10,
                    color: SapemoiTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: SapemoiTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
