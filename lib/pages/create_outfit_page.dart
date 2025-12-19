import 'dart:math';
import '../auth_manager.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../db_manager.dart';
import '../outfit_generator.dart';
import 'complex_outfit_page.dart';

class CreateOutfitPage extends StatefulWidget {
  final List<Clothing> clothes;
  final VoidCallback onUpdate;

  const CreateOutfitPage({super.key, required this.clothes, required this.onUpdate});

  @override
  State<CreateOutfitPage> createState() => _CreateOutfitPageState();
}

class _CreateOutfitPageState extends State<CreateOutfitPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Outfit'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.auto_awesome),
              text: 'Quick Generate',
            ),
            Tab(
              icon: Icon(Icons.layers),
              text: 'By Layers',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _QuickOutfitTab(clothes: widget.clothes, onUpdate: widget.onUpdate),
          ComplexOutfitPage(clothes: widget.clothes),
        ],
      ),
    );
  }
}

class _QuickOutfitTab extends StatefulWidget {
  final List<Clothing> clothes;
  final VoidCallback onUpdate;

  const _QuickOutfitTab({required this.clothes, required this.onUpdate});

  @override
  State<_QuickOutfitTab> createState() => _QuickOutfitTabState();
}

class _QuickOutfitTabState extends State<_QuickOutfitTab> {
  String? selectedSlotType;
  Map<String, Clothing?> outfitSlots = {
    'headwear': null,
    'outerwear': null,
    'top': null,
    'bottom': null,
    'footwear': null,
    'accessory': null,
  };
  Set<String> disabledSlots = {};
  OutfitResult? customOutfitScore;
  bool boldMode = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                SizedBox(
                  width: 350,
                  height: 550,
                  child: _buildCharacterWithSlots(),
                ),
                const SizedBox(height: 24),
                if (customOutfitScore != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getCompatibilityColor((100 - customOutfitScore!.score).toInt()).shade50,
                          _getCompatibilityColor((100 - customOutfitScore!.score).toInt()).shade100,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _getCompatibilityColor((100 - customOutfitScore!.score).toInt()).withOpacity(0.3),
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
                            Text(
                              '${(100 - customOutfitScore!.score).toInt()}% ',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final userModel = await AuthManager().getLocalUser();
                            if (userModel == null) return;
                            final ids = outfitSlots.values.where((e) => e != null).cast<Clothing>().map((c) => c.id).toList();
                            if (ids.isEmpty) return;
                            await DBManager().markOutfitAsUsed(ids, userModel.uid);
                            widget.onUpdate();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Outfit marked as worn!')));
                            }
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Mark as Worn'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        if (selectedSlotType != null) _buildInventoryDrawer(),
      ],
    );
  }

  Widget _buildCharacterWithSlots() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: 125,
          child: _buildSlotButton('headwear', Icons.sports_baseball, 'Hat'),
        ),
        Positioned(
          top: 90,
          left: 10,
          child: _buildSlotButton('accessory', Icons.watch, 'Accessory'),
        ),
        Positioned(
          top: 90,
          right: 10,
          child: _buildSlotButton('outerwear', Icons.checkroom, 'Jacket'),
        ),
        Positioned(
          top: 200,
          right: 10,
          child: _buildSlotButton('sweater', Icons.thermostat, 'Sweater'),
        ),
        Positioned(
          top: 200,
          left: 125,
          child: _buildSlotButton('top', Icons.dry_cleaning, 'Top'),
        ),
        Positioned(
          top: 320,
          left: 125,
          child: _buildSlotButton('bottom', Icons.wallet, 'Bottom'),
        ),
        Positioned(
          top: 450,
          left: 125,
          child: _buildSlotButton('footwear', Icons.shopping_bag, 'Shoes'),
        ),
      ],
    );
  }

  Widget _buildSlotButton(String type, IconData icon, String label) {
    final item = outfitSlots[type];
    final isSelected = selectedSlotType == type;
    final isDisabled = disabledSlots.contains(type);
    final isOptional = type == 'headwear' || type == 'accessory' || type == 'outerwear';

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                selectedSlotType = isSelected ? null : type;
              });
            },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isDisabled ? Colors.grey[300] : (isSelected ? Colors.purple[100] : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDisabled ? Colors.grey : (isSelected ? Colors.purple : Colors.grey[300]!),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: item == null || isDisabled
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 40, color: isDisabled ? Colors.grey[500] : Colors.grey[400]),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDisabled ? Colors.grey[500] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[300],
                              child: const Icon(Icons.checkroom),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              outfitSlots[type] = null;
                              _evaluateCustomOutfit();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          if (isOptional)
            Positioned(
              top: -8,
              left: -8,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isDisabled) {
                      disabledSlots.remove(type);
                    } else {
                      disabledSlots.add(type);
                      outfitSlots[type] = null;
                    }
                    _evaluateCustomOutfit();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDisabled ? Colors.grey : Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isDisabled ? Icons.toggle_off : Icons.toggle_on,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInventoryDrawer() {
    final itemsForType = widget.clothes.where((c) => c.type.toLowerCase() == selectedSlotType!.toLowerCase()).toList();

    return GestureDetector(
      onTap: () => setState(() => selectedSlotType = null),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: MediaQuery.of(context).size.width * 0.95,
              height: MediaQuery.of(context).size.height * 0.8,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getIconForType(selectedSlotType!),
                          size: 32,
                          color: Colors.purple,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _getLabelForType(selectedSlotType!),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => selectedSlotType = null),
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
                                Icon(
                                  _getIconForType(selectedSlotType!),
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No items for ${_getLabelForType(selectedSlotType!)}',
                                  style: const TextStyle(fontSize: 16, color: Colors.grey),
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
                              childAspectRatio: 1.0,
                            ),
                            itemCount: itemsForType.length,
                            itemBuilder: (context, index) {
                              final item = itemsForType[index];
                              final isEquipped = outfitSlots[selectedSlotType] == item;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    outfitSlots[selectedSlotType!] = isEquipped ? null : item;
                                    _evaluateCustomOutfit();
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: isEquipped ? Colors.purple : Colors.grey[200]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                    color: Colors.white,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      item.imageUrl,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const Center(child: CircularProgressIndicator());
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.checkroom),
                                        );
                                      },
                                    ),
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

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'headwear':
        return Icons.sports_baseball;
      case 'outerwear':
        return Icons.checkroom;
      case 'sweater':
        return Icons.thermostat;
      case 'top':
        return Icons.dry_cleaning;
      case 'bottom':
        return Icons.wallet;
      case 'footwear':
        return Icons.shopping_bag;
      case 'accessory':
        return Icons.watch;
      default:
        return Icons.category;
    }
  }

  String _getLabelForType(String type) {
    switch (type.toLowerCase()) {
      case 'headwear':
        return 'Headwear';
      case 'outerwear':
        return 'Jackets & Coats';
      case 'sweater':
        return 'Sweaters';
      case 'top':
        return 'Tops';
      case 'bottom':
        return 'Bottoms';
      case 'footwear':
        return 'Footwear';
      case 'accessory':
        return 'Accessories';
      default:
        return type;
    }
  }

  void _evaluateCustomOutfit() {
    final items = outfitSlots.values.where((item) => item != null).cast<Clothing>().toList();

    if (items.isEmpty) {
      customOutfitScore = null;
      return;
    }

    customOutfitScore = OutfitGenerator.evaluateOutfitWithWeights(items, boldMode: boldMode);
  }

  void _generateBestOutfit() {
    final byType = <String, List<Clothing>>{};
    for (final item in widget.clothes) {
      byType.putIfAbsent(item.type.toLowerCase(), () => []).add(item);
    }

    final preFilledItems = outfitSlots.entries
        .where((entry) => entry.value != null && !disabledSlots.contains(entry.key))
        .map((entry) => entry.value!)
        .toList();

    final emptySlots = outfitSlots.keys.where((type) => outfitSlots[type] == null && !disabledSlots.contains(type)).toList();

    if (emptySlots.isEmpty && preFilledItems.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All slots are disabled or filled!')));
      return;
    }

    final requiredTypes = ['top', 'bottom', 'footwear'];
    for (final type in requiredTypes) {
      final hasPrefilled = preFilledItems.any((item) => item.type.toLowerCase() == type);
      if (!hasPrefilled && (!byType.containsKey(type) || byType[type]!.isEmpty)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not enough items to generate outfit (missing $type)')));
        return;
      }
    }

    final attempts = 100;
    final goodOutfits = <List<Clothing>>[];
    final random = Random();

    for (var i = 0; i < attempts; i++) {
      final outfit = List<Clothing>.from(preFilledItems);

      for (final type in emptySlots) {
        final normalizedType = type.toLowerCase();
        if (byType.containsKey(normalizedType) && byType[normalizedType]!.isNotEmpty) {
          final items = byType[normalizedType]!;
          final randomItem = items[random.nextInt(items.length)];
          outfit.add(randomItem);
        }
      }

      if (outfit.isEmpty) continue;

      final result = OutfitGenerator.evaluateOutfitWithWeights(outfit, boldMode: boldMode);

      if (result.score <= 50) {
        goodOutfits.add(outfit);
      }
    }

    if (goodOutfits.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No good outfit found, try adding more items!')));
      return;
    }

    final selectedIndex = Random().nextInt(goodOutfits.length);
    final bestOutfit = goodOutfits[selectedIndex];

    setState(() {
      for (final item in bestOutfit) {
        final slotType = item.type.toLowerCase();
        if (outfitSlots.containsKey(slotType) && !disabledSlots.contains(slotType) && outfitSlots[slotType] == null) {
          outfitSlots[slotType] = item;
        }
      }
      _evaluateCustomOutfit();
    });

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Best outfit generated!')));
  }

  MaterialColor _getCompatibilityColor(int compatibility) {
    if (compatibility >= 90) return Colors.green;
    if (compatibility >= 75) return Colors.lightGreen;
    if (compatibility >= 60) return Colors.lime;
    if (compatibility >= 45) return Colors.orange;
    if (compatibility >= 30) return Colors.deepOrange;
    return Colors.red;
  }
}
