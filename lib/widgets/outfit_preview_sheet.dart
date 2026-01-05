import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models.dart';
import '../db_manager.dart';
import '../auth_manager.dart';
import '../outfit_generator.dart';
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
    if (score >= 85) return Colors.green;
    if (score >= 75) return Colors.lightGreen;
    if (score >= 60) return Colors.lime;
    if (score >= 45) return Colors.orange;
    if (score >= 30) return Colors.deepOrange;
    return Colors.red;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.photo_camera, color: Colors.purple[700]),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Share Your Style?',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Want to post this outfit to your feed?\n\nShow off your style and inspire others! 📸✨',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
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
            icon: const Icon(Icons.send),
            label: const Text('Post It'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              color: Colors.grey[300],
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
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (compatibility != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getScoreColor(compatibility).withOpacity(0.8),
                              _getScoreColor(compatibility),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _getScoreColor(compatibility).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _getScoreLabel(compatibility),
                        style: TextStyle(
                          color: _getScoreColor(compatibility),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${widget.items.length} pieces',
                        style: TextStyle(
                          color: Colors.grey[600],
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
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '$recentlyWornCount item${recentlyWornCount > 1 ? 's' : ''} worn this week',
                          style: const TextStyle(
                            color: Colors.orange,
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

          const Divider(height: 1),

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
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isMarking ? null : _markAsWorn,
                      icon: _isMarking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(_isMarking ? 'Marking...' : 'Mark as Worn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: Colors.grey[700]),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              if (items.length > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '×${items.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple[700],
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
            height: 120,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecentlyWorn ? Colors.orange.withOpacity(0.5) : Colors.grey[200]!,
          width: isRecentlyWorn ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[100],
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.checkroom, color: Colors.grey[400]),
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
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(8),
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
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
