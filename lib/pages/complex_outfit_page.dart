import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models.dart';
import '../outfit_generator.dart';

class ComplexOutfitPage extends StatefulWidget {
  final List<Clothing> clothes;

  const ComplexOutfitPage({
    super.key,
    required this.clothes,
  });

  @override
  State<ComplexOutfitPage> createState() => _ComplexOutfitPageState();
}

class _ComplexOutfitPageState extends State<ComplexOutfitPage> {
  List<Clothing> _selectedItems = [];
  OutfitResult? _result;
  String? _selectedSlotKey;

  @override
  void initState() {
    super.initState();
  }

  Clothing? _getItemForLayerAndType(int layer, String type) {
    try {
      return _selectedItems.firstWhere(
        (item) => item.layer == layer && item.type == type,
      );
    } catch (e) {
      return null;
    }
  }

  void _toggleItem(int layer, String type, Clothing? newItem) {
    setState(() {
      final existing = _getItemForLayerAndType(layer, type);
      
      if (existing != null) {
        _selectedItems.remove(existing);
      }
      
      if (newItem != null && newItem != existing) {
        _selectedItems.add(newItem);
      }
      
      _result = null;
      _selectedSlotKey = null;
    });
  }

  void _evaluateOutfit() {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = OutfitGenerator.evaluateOutfit(_selectedItems, boldMode: false);
    setState(() => _result = result);
  }

  Color _getLayerColor(int layer) {
    switch (layer) {
      case 0: return Colors.blue.shade400;
      case 1: return Colors.green.shade500;
      case 2: return Colors.orange.shade500;
      case 3: return Colors.red.shade500;
      case 4: return Colors.purple.shade400;
      default: return Colors.grey;
    }
  }

  String _getLayerName(int layer) {
    switch (layer) {
      case 0: return 'Base';
      case 1: return 'Main';
      case 2: return 'Mid';
      case 3: return 'Outer';
      case 4: return 'Accessories';
      default: return 'Layer $layer';
    }
  }

  IconData _getLayerIcon(int layer) {
    switch (layer) {
      case 0: return Icons.checkroom;
      case 1: return Icons.dry_cleaning;
      case 2: return Icons.wallet;
      case 3: return Icons.airline_seat_legroom_extra;
      case 4: return Icons.watch;
      default: return Icons.style;
    }
  }

  Widget _buildLayerSection(int layer) {
    final availableTypes = widget.clothes
        .where((c) => c.layer == layer)
        .map((c) => c.type)
        .toSet()
        .toList();

    if (availableTypes.isEmpty) return const SizedBox.shrink();

    final itemsInLayer = _selectedItems.where((item) => item.layer == layer).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getLayerColor(layer),
                  _getLayerColor(layer).withOpacity(0.7),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(_getLayerIcon(layer), color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  _getLayerName(layer).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                if (itemsInLayer > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$itemsInLayer',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: availableTypes.map((type) {
                return _buildSlotRow(layer, type);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotRow(int layer, String type) {
    final slotKey = '${layer}_$type';
    final item = _getItemForLayerAndType(layer, type);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSlotKey = slotKey;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _selectedSlotKey == slotKey
              ? _getLayerColor(layer).withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedSlotKey == slotKey
                ? _getLayerColor(layer)
                : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: item == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: Colors.grey.shade400),
                        const SizedBox(height: 4),
                        Text(
                          type,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        width: 70,
                        height: 70,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (item != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.specificType,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item.brand,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (item != null)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => _toggleItem(layer, type, null),
              )
            else
              Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryDrawer() {
    final parts = _selectedSlotKey!.split('_');
    final layer = int.parse(parts[0]);
    final type = parts.sublist(1).join('_');

    final itemsForType = widget.clothes
        .where((c) => c.layer == layer && c.type == type)
        .toList();

    final currentItem = _getItemForLayerAndType(layer, type);

    return GestureDetector(
      onTap: () => setState(() => _selectedSlotKey = null),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.75,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getLayerColor(layer),
                          _getLayerColor(layer).withOpacity(0.8),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        Icon(_getLayerIcon(layer), color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                _getLayerName(layer),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => setState(() => _selectedSlotKey = null),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: itemsForType.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  'No items for $type',
                                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: itemsForType.length,
                            itemBuilder: (context, index) {
                              final item = itemsForType[index];
                              final isSelected = currentItem == item;

                              return GestureDetector(
                                onTap: () => _toggleItem(layer, type, isSelected ? null : item),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? _getLayerColor(layer)
                                          : Colors.grey.shade300,
                                      width: isSelected ? 3 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: _getLayerColor(layer).withOpacity(0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: CachedNetworkImage(
                                          imageUrl: item.imageUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          placeholder: (context, url) => Container(
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.error),
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: _getLayerColor(layer),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    if (_result == null) return const SizedBox.shrink();

    final color = _result!.valid ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.shade50, color.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_result!.valid ? Icons.check_circle : Icons.warning, color: color, size: 32),
              const SizedBox(width: 12),
              Text(
                _result!.valid ? 'Valid Outfit!' : 'Has Issues',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Score: ${_result!.score.toStringAsFixed(1)}/100',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color.shade700,
            ),
          ),
          if (_result!.clashes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Color Clashes:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._result!.clashes.map((clash) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '• ${clash.type1} ↔ ${clash.type2}',
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_result != null) _buildResultCard(),
                          _buildLayerSection(0),
                          _buildLayerSection(1),
                          _buildLayerSection(2),
                          _buildLayerSection(3),
                          _buildLayerSection(4),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_selectedSlotKey != null) _buildInventoryDrawer(),
                if (_selectedItems.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _evaluateOutfit,
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text(
                                  'Evaluate Outfit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: const Color(0xFFB86BFF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedItems.clear();
                                  _result = null;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                backgroundColor: Colors.grey.shade300,
                                foregroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Icon(Icons.clear),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
