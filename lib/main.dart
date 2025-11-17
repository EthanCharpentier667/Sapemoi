import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'models.dart';
import 'db_manager.dart';
import 'network_manager.dart';
import 'outfit_generator.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SapemoiApp());
}

class SapemoiApp extends StatelessWidget {
  const SapemoiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sapemoi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          if (snapshot.hasData) {
            return const ContentView();
          }
          
          return const LoginPage();
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const ContentView(),
        '/profile': (context) => const ProfilePage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class ContentView extends StatefulWidget {
  const ContentView({super.key});

  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  List<Clothing> clothes = [];
  List<OutfitWithResult> results = [];
  
  // Modal & Image Picker
  bool showAddModal = false;
  File? pickedImageFile;
  String? pickedImageBase64;
  String newName = '';
  bool analyzing = false;
  
  // Detail Modal
  Clothing? selectedClothing;
  
  bool boldMode = false;
  bool debugShowAll = false;
  
  // Search
  String searchText = '';
  
  // Outfit Generator - Selected Types
  Map<String, bool> selectedTypes = {};
  
  // Create Outfit - Manual slots
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
  
  @override
  void initState() {
    super.initState();
    _loadClothes();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: Stack(
          children: [
            TabBarView(
              children: [
                _buildWardrobeTab(),
                _buildOutfitsTab(),
                _buildCreateOutfitTab(),
                const ProfilePage(),
              ],
            ),
            if (showAddModal) _buildAddModal(),
            if (selectedClothing != null) _buildDetailModal(),
          ],
        ),
        bottomNavigationBar: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.checkroom), text: 'Wardrobe'),
            Tab(icon: Icon(Icons.style), text: 'Outfits'),
            Tab(icon: Icon(Icons.videogame_asset), text: 'Create'),
            Tab(icon: Icon(Icons.person), text: 'Profile'),
          ],
        ),
      ),
    );
  }

  // MARK: - Wardrobe Tab
  Widget _buildWardrobeTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Sapemoi',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add_circle, size: 32),
                        onPressed: () => setState(() => showAddModal = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search clothing...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => setState(() => searchText = value),
                  ),
                ],
              ),
            ),
            // Grid
            Expanded(
              child: _buildClothesGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClothesGrid() {
    final filtered = searchText.isEmpty
        ? clothes
        : clothes.where((c) {
            final query = searchText.toLowerCase();
            return c.name.toLowerCase().contains(query) ||
                   c.type.toLowerCase().contains(query) ||
                   c.brand.toLowerCase().contains(query) ||
                   c.productName.toLowerCase().contains(query);
          }).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text('No clothing items found'),
      );
    }

    final grouped = <String, List<Clothing>>{};
    for (final item in filtered) {
      grouped.putIfAbsent(item.type, () => []).add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        final type = grouped.keys.elementAt(index);
        final items = grouped[type]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Text(
                    type.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${items.length} item${items.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                return ClothingCard(
                  clothing: items[i],
                  onTap: () => setState(() => selectedClothing = items[i]),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // MARK: - Outfits Tab
  Widget _buildOutfitsTab() {
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
                // Liste des types disponibles avec checkbox
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
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              final ids = outfit.outfit.map((c) => c.id).toList();
                              await DBManager().markOutfitAsUsed(ids, user.uid);
                              await _loadClothes();
                              
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

  // MARK: - Methods
  Future<void> _loadClothes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final loaded = await DBManager().getAllClothes(user.uid);
    setState(() {
      clothes = loaded;
      _updateAvailableTypes();
    });
  }

  void _updateAvailableTypes() {
    final types = <String>{};
    for (final item in clothes) {
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

  Future<void> _addClothing() async {
    if (pickedImageBase64 == null || pickedImageFile == null) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => analyzing = true);

    try {
      final result = await NetworkManager().analyzeImage(pickedImageBase64!);

      final clothing = Clothing(
        id: 0,
        name: newName.isEmpty ? 'New Item' : newName,
        imagePath: pickedImageFile!.path,
        imageBase64: pickedImageBase64,
        type: result.type,
        specificType: result.specificType,
        colors: result.colors,
        brand: result.brand,
        productName: result.product,
        createdAt: DateTime.now(),
      );

      await DBManager().addClothing(clothing, user.uid);
      await _loadClothes();

      setState(() {
        showAddModal = false;
        pickedImageFile = null;
        pickedImageBase64 = null;
        newName = '';
        analyzing = false;
      });
    } catch (e) {
      setState(() => analyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least a top, bottom, or dress')),
      );
      return;
    }
    
    final allByType = <String, List<Clothing>>{};
    for (final item in clothes) {
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

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);

    if (image != null) {
      final file = File(image.path);
      final bytes = await file.readAsBytes();
      final base64 = base64Encode(bytes);

      setState(() {
        pickedImageFile = file;
        pickedImageBase64 = base64;
      });
    }
  }

  // MARK: - Add Modal
  Widget _buildAddModal() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Row(
                children: [
                  const Text(
                    'Add Clothing',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      showAddModal = false;
                      pickedImageFile = null;
                      pickedImageBase64 = null;
                      newName = '';
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (pickedImageFile != null)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(pickedImageFile!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => newName = value,
              ),
              const SizedBox(height: 16),
              if (analyzing)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: pickedImageFile != null ? _addClothing : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Analyze & Add'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // MARK: - Detail Modal
  Widget _buildDetailModal() {
    return ClothingDetailModal(
      clothing: selectedClothing!,
      onClose: () => setState(() => selectedClothing = null),
      onUpdate: _loadClothes,
    );
  }
  
  String? selectedSlotType;
  
  // MARK: - Create Outfit Tab
  Widget _buildCreateOutfitTab() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Your Outfit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Generate Best Outfit',
            onPressed: _generateBestOutfit,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                outfitSlots = {
                  'headwear': null,
                  'outerwear': null,
                  'top': null,
                  'bottom': null,
                  'footwear': null,
                  'accessory': null,
                };
                customOutfitScore = null;
                selectedSlotType = null;
              });
            },
          ),
        ],
      ),
      body: Stack(
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
                              Icon(
                                Icons.stars,
                                color: _getCompatibilityColor((100 - customOutfitScore!.score).toInt()),
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${(100 - customOutfitScore!.score).toInt()}% Compatibility',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _getCompatibilityColor((100 - customOutfitScore!.score).toInt()),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                final items = outfitSlots.values.where((item) => item != null).cast<Clothing>().toList();
                                final ids = items.map((c) => c.id).toList();
                                await DBManager().markOutfitAsUsed(ids, user.uid);
                                await _loadClothes();
                                
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Outfit marked as worn!')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Mark as Worn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getCompatibilityColor((100 - customOutfitScore!.score).toInt()),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
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
      ),
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
      onTap: isDisabled ? null : () {
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
                        child: item.imageBase64 != null
                            ? Image.memory(
                                base64Decode(item.imageBase64!),
                                fit: BoxFit.cover,
                                width: 100,
                                height: 100,
                              )
                            : Image.file(
                                File(item.imagePath),
                                fit: BoxFit.cover,
                                width: 100,
                                height: 100,
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
    final itemsForType = clothes.where((c) => c.type.toLowerCase() == selectedSlotType!.toLowerCase()).toList();
    
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
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No ${_getLabelForType(selectedSlotType!).toLowerCase()} in your wardrobe',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
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
                                    outfitSlots[selectedSlotType!] = item;
                                    _evaluateCustomOutfit();
                                    selectedSlotType = null;
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isEquipped ? Colors.purple : Colors.grey[300]!,
                                      width: isEquipped ? 4 : 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: item.imageBase64 != null
                                            ? Image.memory(
                                                base64Decode(item.imageBase64!),
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                              )
                                            : Image.file(
                                                File(item.imagePath),
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                              ),
                                      ),
                                      if (isEquipped)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.purple,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.purple.withOpacity(0.5),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              size: 24,
                                              color: Colors.white,
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
  
  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'headwear': return Icons.sports_baseball;
      case 'outerwear': return Icons.checkroom;
      case 'top': return Icons.dry_cleaning;
      case 'bottom': return Icons.wallet;
      case 'footwear': return Icons.shopping_bag;
      case 'accessory': return Icons.watch;
      default: return Icons.category;
    }
  }
  
  String _getLabelForType(String type) {
    switch (type.toLowerCase()) {
      case 'headwear': return 'Headwear';
      case 'outerwear': return 'Jackets & Coats';
      case 'top': return 'Tops';
      case 'bottom': return 'Bottoms';
      case 'footwear': return 'Footwear';
      case 'accessory': return 'Accessories';
      default: return type;
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
    for (final item in clothes) {
      byType.putIfAbsent(item.type.toLowerCase(), () => []).add(item);
    }
    
    final preFilledItems = outfitSlots.entries
        .where((entry) => entry.value != null && !disabledSlots.contains(entry.key))
        .map((entry) => entry.value!)
        .toList();
    
    final emptySlots = outfitSlots.keys
        .where((type) => outfitSlots[type] == null && !disabledSlots.contains(type))
        .toList();
    
    if (emptySlots.isEmpty && preFilledItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All slots are disabled or filled!')),
      );
      return;
    }
    
    final requiredTypes = ['top', 'bottom', 'footwear'];
    for (final type in requiredTypes) {
      final hasPrefilled = preFilledItems.any((item) => item.type.toLowerCase() == type);
      if (!hasPrefilled && (!byType.containsKey(type) || byType[type]!.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not enough items to generate outfit (missing $type)')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No good outfit found, try adding more items!')),
      );
      return;
    }
    
    final selectedIndex = random.nextInt(goodOutfits.length);
    final bestOutfit = goodOutfits[selectedIndex];
    
    setState(() {
      for (final item in bestOutfit) {
        final slotType = item.type.toLowerCase();
        if (outfitSlots.containsKey(slotType) && 
            !disabledSlots.contains(slotType) && 
            outfitSlots[slotType] == null) {
          outfitSlots[slotType] = item;
        }
      }
      _evaluateCustomOutfit();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Best outfit generated!')),
    );
  }
  
  MaterialColor _getRatingColor(int compatibility) {
    if (compatibility >= 85) return Colors.purple;
    if (compatibility >= 70) return Colors.green;
    if (compatibility >= 55) return Colors.blue;
    if (compatibility >= 40) return Colors.orange;
    return Colors.red;
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

class OutfitWithResult {
  final List<Clothing> outfit;
  final OutfitResult result;
  final double recencyWeight;

  OutfitWithResult({required this.outfit, required this.result, required this.recencyWeight});
}

// MARK: - Clothing Detail Modal
class ClothingDetailModal extends StatefulWidget {
  final Clothing clothing;
  final VoidCallback onClose;
  final VoidCallback onUpdate;

  const ClothingDetailModal({
    super.key,
    required this.clothing,
    required this.onClose,
    required this.onUpdate,
  });

  @override
  State<ClothingDetailModal> createState() => _ClothingDetailModalState();
}

class _ClothingDetailModalState extends State<ClothingDetailModal> {
  late TextEditingController _brandController;
  late TextEditingController _productController;
  bool _isEditingBrand = false;
  bool _isEditingProduct = false;
  bool _isEditingColors = false;
  late List<ColorInfo> _editableColors;

  @override
  void initState() {
    super.initState();
    _brandController = TextEditingController(text: widget.clothing.brand);
    _productController = TextEditingController(text: widget.clothing.productName);
    _editableColors = List.from(widget.clothing.colors);
  }

  @override
  void dispose() {
    _brandController.dispose();
    _productController.dispose();
    super.dispose();
  }

  Future<void> _saveBrand() async {
    final updated = Clothing(
      id: widget.clothing.id,
      name: widget.clothing.name,
      imagePath: widget.clothing.imagePath,
      imageBase64: widget.clothing.imageBase64,
      type: widget.clothing.type,
      specificType: widget.clothing.specificType,
      colors: widget.clothing.colors,
      brand: _brandController.text.trim(),
      productName: widget.clothing.productName,
      createdAt: widget.clothing.createdAt,
      wearCount: widget.clothing.wearCount,
      lastWorn: widget.clothing.lastWorn,
      estimatedValue: widget.clothing.estimatedValue,
    );

    await DBManager().updateClothing(updated);
    widget.onUpdate();
    setState(() => _isEditingBrand = false);
  }

  Future<void> _saveProduct() async {
    final updated = Clothing(
      id: widget.clothing.id,
      name: widget.clothing.name,
      imagePath: widget.clothing.imagePath,
      imageBase64: widget.clothing.imageBase64,
      type: widget.clothing.type,
      specificType: widget.clothing.specificType,
      colors: widget.clothing.colors,
      brand: widget.clothing.brand,
      productName: _productController.text.trim(),
      createdAt: widget.clothing.createdAt,
      wearCount: widget.clothing.wearCount,
      lastWorn: widget.clothing.lastWorn,
      estimatedValue: widget.clothing.estimatedValue,
    );

    await DBManager().updateClothing(updated);
    widget.onUpdate();
    setState(() => _isEditingProduct = false);
  }
  
  Future<void> _saveColors() async {
    final updated = Clothing(
      id: widget.clothing.id,
      name: widget.clothing.name,
      imagePath: widget.clothing.imagePath,
      imageBase64: widget.clothing.imageBase64,
      type: widget.clothing.type,
      specificType: widget.clothing.specificType,
      colors: _editableColors,
      brand: widget.clothing.brand,
      productName: widget.clothing.productName,
      createdAt: widget.clothing.createdAt,
      wearCount: widget.clothing.wearCount,
      lastWorn: widget.clothing.lastWorn,
      estimatedValue: widget.clothing.estimatedValue,
    );

    await DBManager().updateClothing(updated);
    widget.onUpdate();
    setState(() => _isEditingColors = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Details',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await DBManager().deleteClothing(widget.clothing.id);
                        widget.onUpdate();
                        widget.onClose();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.clothing.imageBase64 != null)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: MemoryImage(base64Decode(widget.clothing.imageBase64!)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(File(widget.clothing.imagePath)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _buildInfoRow('Name', widget.clothing.name),
                _buildInfoRow('Type', widget.clothing.type),
                
                // Editable Brand
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Text(
                        'Brand:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isEditingBrand
                            ? TextField(
                                controller: _brandController,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  border: OutlineInputBorder(),
                                ),
                              )
                            : Text(_brandController.text),
                      ),
                      IconButton(
                        icon: Icon(_isEditingBrand ? Icons.check : Icons.edit, size: 20),
                        onPressed: () {
                          if (_isEditingBrand) {
                            _saveBrand();
                          } else {
                            setState(() => _isEditingBrand = true);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                
                // Editable Product
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Text(
                        'Product:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isEditingProduct
                            ? TextField(
                                controller: _productController,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  border: OutlineInputBorder(),
                                ),
                              )
                            : Text(_productController.text),
                      ),
                      IconButton(
                        icon: Icon(_isEditingProduct ? Icons.check : Icons.edit, size: 20),
                        onPressed: () {
                          if (_isEditingProduct) {
                            _saveProduct();
                          } else {
                            setState(() => _isEditingProduct = true);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Colors',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(_isEditingColors ? Icons.check : Icons.edit, size: 20),
                      onPressed: () {
                        if (_isEditingColors) {
                          _saveColors();
                        } else {
                          setState(() => _isEditingColors = true);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isEditingColors)
                  Column(
                    children: [
                      ..._editableColors.asMap().entries.map((entry) {
                        final index = entry.key;
                        final color = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Color.fromRGBO(color.r, color.g, color.b, 1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('RGB: ${color.r}, ${color.g}, ${color.b}'),
                                    Row(
                                      children: [
                                        const Text('% :'),
                                        Expanded(
                                          child: Slider(
                                            value: color.pct.toDouble(),
                                            min: 0,
                                            max: 100,
                                            divisions: 20,
                                            label: '${color.pct}%',
                                            onChanged: (value) {
                                              setState(() {
                                                _editableColors[index] = ColorInfo(
                                                  r: color.r,
                                                  g: color.g,
                                                  b: color.b,
                                                  pct: value.toInt(),
                                                );
                                              });
                                            },
                                          ),
                                        ),
                                        Text('${color.pct}%'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: _editableColors.length > 1
                                    ? () {
                                        setState(() {
                                          _editableColors.removeAt(index);
                                        });
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      if (_editableColors.length < 5)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _editableColors.add(ColorInfo(r: 128, g: 128, b: 128, pct: 10));
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Color'),
                        ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _editableColors.map((color) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(color.r, color.g, color.b, 1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${color.pct}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: widget.onClose,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

// MARK: - Clothing Card
class ClothingCard extends StatelessWidget {
  final Clothing clothing;
  final VoidCallback onTap;

  const ClothingCard({
    super.key,
    required this.clothing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: clothing.imageBase64 != null
                    ? Image.memory(
                        base64Decode(clothing.imageBase64!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : Image.file(
                        File(clothing.imagePath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stack) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, size: 48),
                          );
                        },
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clothing.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    clothing.brand,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
