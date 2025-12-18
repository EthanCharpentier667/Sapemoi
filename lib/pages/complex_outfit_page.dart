import 'package:flutter/material.dart';
import '../models.dart';
import '../db_manager.dart';
import '../outfit_generator.dart';
import '../auth_manager.dart';
import '../widgets/clothing_card.dart';

class ComplexOutfitPage extends StatefulWidget {
  const ComplexOutfitPage({super.key});

  @override
  State<ComplexOutfitPage> createState() => _ComplexOutfitPageState();
}

class _ComplexOutfitPageState extends State<ComplexOutfitPage> {
  List<Clothing> _allClothes = [];
  List<Clothing> _selectedItems = [];
  bool _isLoading = true;
  OutfitResult? _result;

  @override
  void initState() {
    super.initState();
    _loadClothes();
  }

  Future<void> _loadClothes() async {
    setState(() => _isLoading = true);
    final userModel = await AuthManager().getLocalUser();
    if (userModel == null) {
      setState(() => _isLoading = false);
      return;
    }
    final clothes = await DBManager().getAllClothes(userModel.uid);
    setState(() {
      _allClothes = clothes;
      _isLoading = false;
    });
  }

  bool _canAddItem(Clothing item) {
    for (final selected in _selectedItems) {
      if (selected.type.toLowerCase() == item.type.toLowerCase() &&
          selected.layer == item.layer) {
        return false;
      }
    }
    return true;
  }

  void _toggleItem(Clothing item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
      } else {
        if (_canAddItem(item)) {
          _selectedItems.add(item);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot add ${item.specificType}: already have a ${item.type} on layer ${item.layer}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      _result = null;
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

    final result = OutfitGenerator.evaluateOutfit(
      _selectedItems,
      boldMode: false,
    );

    setState(() {
      _result = result;
    });
  }

  Map<int, List<Clothing>> _groupByLayer() {
    final grouped = <int, List<Clothing>>{};
    for (final item in _selectedItems) {
      grouped.putIfAbsent(item.layer, () => []).add(item);
    }
    return grouped;
  }

  Widget _buildLayerVisualization() {
    final layerGroups = _groupByLayer();
    final sortedLayers = layerGroups.keys.toList()..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Outfit Layers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...sortedLayers.map((layer) {
              final items = layerGroups[layer]!;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getLayerColor(layer),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getLayerName(layer),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: items.map((item) {
                          return Chip(
                            label: Text(
                              item.specificType,
                              style: const TextStyle(fontSize: 12),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => _toggleItem(item),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  String _getLayerName(int layer) {
    switch (layer) {
      case 0:
        return 'Base';
      case 1:
        return 'Main';
      case 2:
        return 'Mid';
      case 3:
        return 'Outer';
      default:
        return 'L$layer';
    }
  }

  Color _getLayerColor(int layer) {
    switch (layer) {
      case 0:
        return Colors.blue.shade300;
      case 1:
        return Colors.green.shade400;
      case 2:
        return Colors.orange.shade400;
      case 3:
        return Colors.red.shade400;
      default:
        return Colors.grey;
    }
  }

  Widget _buildResultCard() {
    if (_result == null) return const SizedBox.shrink();

    final result = _result!;
    final color = result.valid
        ? Colors.green
        : result.score > 60
            ? Colors.red
            : Colors.orange;

    return Card(
      color: color.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.valid ? Icons.check_circle : Icons.warning,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  result.valid ? 'Valid Outfit!' : 'Issues Detected',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Score: ${result.score.toStringAsFixed(1)}/100',
              style: TextStyle(
                fontSize: 16,
                color: color.shade700,
              ),
            ),
            if (result.clashes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Color Clashes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...result.clashes.map((clash) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '• ${clash.type1} ↔ ${clash.type2} (${clash.score.toStringAsFixed(1)})',
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complex Outfit Builder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClothes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_selectedItems.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildLayerVisualization(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _evaluateOutfit,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Evaluate Outfit'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedItems.clear();
                              _result = null;
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildResultCard(),
                  ),
                ],
                Expanded(
                  child: _allClothes.isEmpty
                      ? const Center(
                          child: Text('No clothing items found'),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16.0),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _allClothes.length,
                          itemBuilder: (context, index) {
                            final item = _allClothes[index];
                            final isSelected = _selectedItems.contains(item);
                            final canAdd = _canAddItem(item);

                            return Stack(
                              children: [
                                ClothingCard(
                                  clothing: item,
                                  onTap: () => _toggleItem(item),
                                ),
                                if (!canAdd && !isSelected)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black54,
                                      child: const Center(
                                        child: Icon(
                                          Icons.block,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (isSelected)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getLayerColor(item.layer),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getLayerName(item.layer),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
