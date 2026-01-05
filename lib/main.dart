import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'models.dart';
import 'db_manager.dart';
import 'auth_manager.dart';
import 'network_manager.dart';
import 'theme.dart';
import 'pages/login_page.dart';
import 'pages/profile_page.dart';
import 'pages/recommendations_page.dart';
import 'pages/wardrobe_page.dart';
import 'pages/create_outfit_page.dart';
import 'pages/outfit_generator_page.dart';
import 'pages/feed_page.dart';
import 'widgets/splash_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Status bar style for dark theme
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: SapemoiTheme.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  
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
      theme: SapemoiTheme.darkTheme,
      darkTheme: SapemoiTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const AuthGate(),
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

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

enum _AuthStatus { loading, signedOut, signedIn }

class _AuthGateState extends State<AuthGate> {
  _AuthStatus _status = _AuthStatus.loading;
  late final Stream<User?> _authStream;
  late final StreamSubscription<User?> _sub;
  String? _lastCheckedUid;

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();
    _sub = _authStream.listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (!mounted) return;
    if (user == null) {
      _lastCheckedUid = null;
      setState(() => _status = _AuthStatus.signedOut);
      return;
    }

    if (_lastCheckedUid == user.uid && _status == _AuthStatus.signedIn) {
      return;
    }

    setState(() => _status = _AuthStatus.loading);
    _lastCheckedUid = user.uid;
    
    final remote = await AuthManager().getLocalUser();
    if (remote == null) {
      setState(() => _status = _AuthStatus.signedOut);
    } else {
      setState(() => _status = _AuthStatus.signedIn);
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_status == _AuthStatus.loading) {
      return const Scaffold(
        body: SplashScreen(),
      );
    }
    if (_status == _AuthStatus.signedIn) {
      return const ContentView();
    }
    return const LoginPage();
  }
}

class _ContentViewState extends State<ContentView> {
  List<Clothing> clothes = [];
  bool showAddModal = false;
  File? pickedImageFile;
  String? pickedImageBase64;
  String newName = '';
  bool analyzing = false;
  Clothing? selectedClothing;
  String searchText = '';
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
  bool _isLoadingData = true;
  int _currentIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _loadClothes();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(
        body: SplashScreen(),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          WardrobePage(
            clothes: clothes,
            searchText: searchText,
            onSearchChanged: (value) => setState(() => searchText = value),
            onAddPressed: () => setState(() => showAddModal = true),
            onClothingTap: (clothing) => _showClothingDetail(clothing),
          ),
          const FeedPage(),
          OutfitGeneratorPage(
            clothes: clothes,
            onUpdate: _loadClothes,
          ),
          CreateOutfitPage(
            clothes: clothes,
            onUpdate: _loadClothes,
          ),
          RecommendationsPage(
            clothes: clothes,
            onUpdate: _loadClothes,
          ),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      // Floating modals
      floatingActionButton: showAddModal || selectedClothing != null
          ? null
          : null,
      extendBody: true,
    );
  }
  
  void _showClothingDetail(Clothing clothing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClothingDetailSheet(
        clothing: clothing,
        onUpdate: () {
          _loadClothes();
          Navigator.pop(context);
        },
        onDelete: () async {
          await DBManager().deleteClothing(clothing.id);
          _loadClothes();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }
  
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: SapemoiTheme.surface,
        border: Border(
          top: BorderSide(
            color: SapemoiTheme.border.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.checkroom_outlined, Icons.checkroom, 'Wardrobe'),
              _buildNavItem(1, Icons.explore_outlined, Icons.explore, 'Feed'),
              _buildNavItem(2, Icons.auto_awesome_outlined, Icons.auto_awesome, 'Generate'),
              _buildNavItem(3, Icons.gesture_outlined, Icons.gesture, 'Create'),
              _buildNavItem(4, Icons.shopping_bag_outlined, Icons.shopping_bag, 'Shop'),
              _buildNavItem(5, Icons.person_outline, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? SapemoiTheme.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? SapemoiTheme.primary : SapemoiTheme.textMuted,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? SapemoiTheme.primary : SapemoiTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadClothes() async {
    final userModel = await AuthManager().getLocalUser();
    if (userModel == null) {
      setState(() => _isLoadingData = false);
      return;
    }

    final loaded = await DBManager().getAllClothes(userModel.uid);
    
    // Précharger toutes les images
    final imagePreloadFutures = loaded.map((clothing) {
      return precacheImage(
        NetworkImage(clothing.imageUrl),
        context,
      );
    }).toList();
    
    // Attendre que toutes les images soient chargées
    await Future.wait(imagePreloadFutures);
    
    setState(() {
      clothes = loaded;
      _isLoadingData = false;
    });
  }
  

  Future<void> _addClothing() async {
    if (pickedImageBase64 == null || pickedImageFile == null) return;
    
    final userModel = await AuthManager().getLocalUser();
    if (userModel == null) return;

    setState(() => analyzing = true);

    try {
      final imageUrl = await NetworkManager().uploadImage(pickedImageBase64!);
      if (imageUrl == null) {
        throw Exception('Failed to upload image');
      }

      final result = await NetworkManager().analyzeImage(imageUrl);

      final clothing = Clothing(
        id: 0,
        name: newName.isEmpty ? 'New Item' : newName,
        imageUrl: imageUrl,
        type: result.type,
        specificType: result.specificType,
        layer: result.layer,
        colors: result.colors,
        brand: result.brand,
        productName: result.product,
        createdAt: DateTime.now(),
      );

      await DBManager().addClothing(clothing, userModel.uid);
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
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => newName = value),
              ),
              const SizedBox(height: 16),
              if (analyzing)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: pickedImageFile != null && newName.trim().isNotEmpty ? _addClothing : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: pickedImageFile != null && newName.trim().isNotEmpty 
                        ? null 
                        : Colors.grey[300],
                    foregroundColor: pickedImageFile != null && newName.trim().isNotEmpty 
                        ? null 
                        : Colors.grey[600],
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
  
}

class OutfitWithResult {
  final List<Clothing> outfit;
  final OutfitResult result;
  final double recencyWeight;

  OutfitWithResult({required this.outfit, required this.result, required this.recencyWeight});
}

// MARK: - Clothing Detail Sheet (Dark Theme)
class ClothingDetailSheet extends StatefulWidget {
  final Clothing clothing;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const ClothingDetailSheet({
    super.key,
    required this.clothing,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<ClothingDetailSheet> createState() => _ClothingDetailSheetState();
}

class _ClothingDetailSheetState extends State<ClothingDetailSheet> {
  late TextEditingController _brandController;
  late TextEditingController _productController;
  bool _isEditingType = false;
  String _selectedType = '';
  bool _isEditingBrand = false;
  bool _isEditingProduct = false;
  bool _isEditingColors = false;
  late List<ColorInfo> _editableColors;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _brandController = TextEditingController(text: widget.clothing.brand);
    _productController = TextEditingController(text: widget.clothing.productName);
    _editableColors = List.from(widget.clothing.colors);
    _selectedType = widget.clothing.type;
  }

  @override
  void dispose() {
    _brandController.dispose();
    _productController.dispose();
    super.dispose();
  }

  Future<void> _saveField(String field) async {
    setState(() => _isSaving = true);
    
    final updated = Clothing(
      id: widget.clothing.id,
      name: widget.clothing.name,
      imageUrl: widget.clothing.imageUrl,
      type: field == 'type' ? _selectedType : widget.clothing.type,
      specificType: widget.clothing.specificType,
      colors: field == 'colors' ? _editableColors : widget.clothing.colors,
      brand: field == 'brand' ? _brandController.text.trim() : widget.clothing.brand,
      productName: field == 'product' ? _productController.text.trim() : widget.clothing.productName,
      createdAt: widget.clothing.createdAt,
      wearCount: widget.clothing.wearCount,
      lastWorn: widget.clothing.lastWorn,
      estimatedValue: widget.clothing.estimatedValue,
    );

    await DBManager().updateClothing(updated);
    
    setState(() {
      _isSaving = false;
      if (field == 'type') _isEditingType = false;
      if (field == 'brand') _isEditingBrand = false;
      if (field == 'product') _isEditingProduct = false;
      if (field == 'colors') _isEditingColors = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${field.substring(0, 1).toUpperCase()}${field.substring(1)} updated'),
          backgroundColor: SapemoiTheme.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: SapemoiTheme.background,
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
              color: SapemoiTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Text(
                  'Clothing Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: SapemoiTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  onPressed: () => _showDeleteConfirmation(),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: SapemoiTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          const Divider(color: SapemoiTheme.border, height: 1),
          
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: SapemoiTheme.surface,
                      borderRadius: BorderRadius.circular(SapemoiTheme.radiusLg),
                      border: Border.all(color: SapemoiTheme.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(SapemoiTheme.radiusLg - 1),
                      child: CachedNetworkImage(
                        imageUrl: widget.clothing.imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: SapemoiTheme.primary),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.broken_image,
                          color: SapemoiTheme.textMuted,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Name (non editable)
                  _buildDisplayField('Name', widget.clothing.name),
                  
                  const SizedBox(height: 16),
                  
                  // Type (editable dropdown)
                  _buildEditableDropdown(
                    label: 'Type',
                    value: _selectedType,
                    isEditing: _isEditingType,
                    options: ['top', 'sweater', 'outerwear', 'bottom', 'footwear', 'headwear', 'accessory', 'dress', 'underwear'],
                    onEdit: () => setState(() => _isEditingType = true),
                    onSave: () => _saveField('type'),
                    onCancel: () => setState(() {
                      _isEditingType = false;
                      _selectedType = widget.clothing.type;
                    }),
                    onChanged: (v) => setState(() => _selectedType = v),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Brand (editable)
                  _buildEditableField(
                    label: 'Brand',
                    controller: _brandController,
                    isEditing: _isEditingBrand,
                    onEdit: () => setState(() => _isEditingBrand = true),
                    onSave: () => _saveField('brand'),
                    onCancel: () => setState(() {
                      _isEditingBrand = false;
                      _brandController.text = widget.clothing.brand;
                    }),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Product (editable)
                  _buildEditableField(
                    label: 'Product',
                    controller: _productController,
                    isEditing: _isEditingProduct,
                    onEdit: () => setState(() => _isEditingProduct = true),
                    onSave: () => _saveField('product'),
                    onCancel: () => setState(() {
                      _isEditingProduct = false;
                      _productController.text = widget.clothing.productName;
                    }),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Colors section
                  _buildColorsSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Stats
                  _buildStatsSection(),
                  
                  const SizedBox(height: 32),
                  
                  // Done button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onUpdate();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SapemoiTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDisplayField(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SapemoiTheme.surface,
        borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
        border: Border.all(color: SapemoiTheme.border),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: SapemoiTheme.textMuted,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: SapemoiTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required VoidCallback onCancel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SapemoiTheme.surface,
        borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
        border: Border.all(
          color: isEditing ? SapemoiTheme.primary.withOpacity(0.5) : SapemoiTheme.border,
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: SapemoiTheme.textMuted,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: isEditing
                ? TextField(
                    controller: controller,
                    style: TextStyle(
                      color: SapemoiTheme.textPrimary,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                  )
                : Text(
                    controller.text,
                    style: TextStyle(
                      color: SapemoiTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
          ),
          const SizedBox(width: 8),
          if (isEditing) ...[
            GestureDetector(
              onTap: onCancel,
              child: Icon(Icons.close, color: SapemoiTheme.textMuted, size: 20),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isSaving ? null : onSave,
              child: Icon(
                Icons.check,
                color: _isSaving ? SapemoiTheme.textMuted : SapemoiTheme.primary,
                size: 20,
              ),
            ),
          ] else
            GestureDetector(
              onTap: onEdit,
              child: Icon(Icons.edit_outlined, color: SapemoiTheme.textMuted, size: 18),
            ),
        ],
      ),
    );
  }
  
  Widget _buildEditableDropdown({
    required String label,
    required String value,
    required bool isEditing,
    required List<String> options,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required VoidCallback onCancel,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SapemoiTheme.surface,
        borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
        border: Border.all(
          color: isEditing ? SapemoiTheme.primary.withOpacity(0.5) : SapemoiTheme.border,
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: SapemoiTheme.textMuted,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: isEditing
                ? DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: value,
                      isExpanded: true,
                      dropdownColor: SapemoiTheme.surfaceLight,
                      style: TextStyle(
                        color: SapemoiTheme.textPrimary,
                        fontSize: 15,
                      ),
                      items: options.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          t.substring(0, 1).toUpperCase() + t.substring(1),
                          textAlign: TextAlign.right,
                        ),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) onChanged(v);
                      },
                    ),
                  )
                : Text(
                    value.substring(0, 1).toUpperCase() + value.substring(1),
                    style: TextStyle(
                      color: SapemoiTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
          ),
          const SizedBox(width: 8),
          if (isEditing) ...[
            GestureDetector(
              onTap: onCancel,
              child: Icon(Icons.close, color: SapemoiTheme.textMuted, size: 20),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isSaving ? null : onSave,
              child: Icon(
                Icons.check,
                color: _isSaving ? SapemoiTheme.textMuted : SapemoiTheme.primary,
                size: 20,
              ),
            ),
          ] else
            GestureDetector(
              onTap: onEdit,
              child: Icon(Icons.edit_outlined, color: SapemoiTheme.textMuted, size: 18),
            ),
        ],
      ),
    );
  }
  
  Widget _buildColorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Colors',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: SapemoiTheme.textPrimary,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                if (_isEditingColors) {
                  _saveField('colors');
                } else {
                  setState(() => _isEditingColors = true);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isEditingColors ? SapemoiTheme.primary : SapemoiTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
                ),
                child: Text(
                  _isEditingColors ? 'Save' : 'Edit',
                  style: TextStyle(
                    color: _isEditingColors ? Colors.white : SapemoiTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (_isEditingColors)
          _buildColorEditor()
        else
          _buildColorDisplay(),
      ],
    );
  }
  
  Widget _buildColorDisplay() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _editableColors.map((color) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Color.fromRGBO(color.r, color.g, color.b, 1),
                borderRadius: BorderRadius.circular(SapemoiTheme.radiusSm),
                border: Border.all(color: SapemoiTheme.border),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${color.pct}%',
              style: TextStyle(
                fontSize: 11,
                color: SapemoiTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
  
  Widget _buildColorEditor() {
    return Column(
      children: [
        ..._editableColors.asMap().entries.map((entry) {
          final index = entry.key;
          final color = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SapemoiTheme.surface,
              borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
              border: Border.all(color: SapemoiTheme.primary.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                // Header with color preview and delete
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showColorPickerDialog(index, color),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(color.r, color.g, color.b, 1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: SapemoiTheme.border, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromRGBO(color.r, color.g, color.b, 0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.colorize,
                          color: _getContrastColor(color.r, color.g, color.b),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Color ${index + 1}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: SapemoiTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to pick color',
                            style: TextStyle(
                              fontSize: 12,
                              color: SapemoiTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: SapemoiTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
                      ),
                      child: Text(
                        '${color.pct}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: SapemoiTheme.primary,
                        ),
                      ),
                    ),
                    if (_editableColors.length > 1) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _editableColors.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.close, color: Colors.red.shade400, size: 18),
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // RGB Sliders
                _buildRGBSlider('R', color.r, Colors.red, (value) {
                  setState(() {
                    _editableColors[index] = ColorInfo(r: value, g: color.g, b: color.b, pct: color.pct);
                  });
                }),
                const SizedBox(height: 8),
                _buildRGBSlider('G', color.g, Colors.green, (value) {
                  setState(() {
                    _editableColors[index] = ColorInfo(r: color.r, g: value, b: color.b, pct: color.pct);
                  });
                }),
                const SizedBox(height: 8),
                _buildRGBSlider('B', color.b, Colors.blue, (value) {
                  setState(() {
                    _editableColors[index] = ColorInfo(r: color.r, g: color.g, b: value, pct: color.pct);
                  });
                }),
                
                const SizedBox(height: 12),
                const Divider(color: SapemoiTheme.border),
                const SizedBox(height: 8),
                
                // Percentage slider
                Row(
                  children: [
                    Icon(Icons.pie_chart, size: 16, color: SapemoiTheme.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Coverage',
                      style: TextStyle(
                        fontSize: 13,
                        color: SapemoiTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: SapemoiTheme.primary,
                          inactiveTrackColor: SapemoiTheme.surfaceLight,
                          thumbColor: SapemoiTheme.primary,
                          overlayColor: SapemoiTheme.primary.withOpacity(0.2),
                          trackHeight: 6,
                        ),
                        child: Slider(
                          value: color.pct.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 20,
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
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        
        // Add color button
        if (_editableColors.length < 5)
          GestureDetector(
            onTap: () {
              setState(() {
                _editableColors.add(ColorInfo(r: 30, g: 30, b: 30, pct: 10));
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: SapemoiTheme.surface,
                borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
                border: Border.all(color: SapemoiTheme.border, style: BorderStyle.solid),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: SapemoiTheme.textSecondary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Add Color',
                    style: TextStyle(
                      color: SapemoiTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildRGBSlider(String label, int value, Color trackColor, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: trackColor,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: trackColor,
              inactiveTrackColor: trackColor.withOpacity(0.2),
              thumbColor: trackColor,
              overlayColor: trackColor.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              onChanged: (v) => onChanged(v.toInt()),
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 12,
              color: SapemoiTheme.textSecondary,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
  
  Color _getContrastColor(int r, int g, int b) {
    final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
  
  void _showColorPickerDialog(int index, ColorInfo currentColor) {
    int tempR = currentColor.r;
    int tempG = currentColor.g;
    int tempB = currentColor.b;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: SapemoiTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SapemoiTheme.radiusLg),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SapemoiTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.palette, color: SapemoiTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Pick Color',
                style: TextStyle(color: SapemoiTheme.textPrimary, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 280,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Preview
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(tempR, tempG, tempB, 1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: SapemoiTheme.border),
                    ),
                    child: Center(
                      child: Text(
                        '#${tempR.toRadixString(16).padLeft(2, '0')}${tempG.toRadixString(16).padLeft(2, '0')}${tempB.toRadixString(16).padLeft(2, '0')}'.toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getContrastColor(tempR, tempG, tempB),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Color grid - reduced to 18 colors
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildColorGridItem(setDialogState, 0, 0, 0, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      _buildColorGridItem(setDialogState, 255, 255, 255, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      _buildColorGridItem(setDialogState, 128, 128, 128, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      _buildColorGridItem(setDialogState, 64, 64, 64, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      _buildColorGridItem(setDialogState, 220, 200, 170, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      _buildColorGridItem(setDialogState, 100, 60, 30, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      
                      _buildColorGridItem(setDialogState, 220, 40, 40, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      _buildColorGridItem(setDialogState, 255, 140, 0, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      _buildColorGridItem(setDialogState, 255, 200, 0, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      _buildColorGridItem(setDialogState, 40, 180, 80, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      _buildColorGridItem(setDialogState, 0, 128, 128, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      _buildColorGridItem(setDialogState, 40, 80, 180, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      
                      _buildColorGridItem(setDialogState, 15, 30, 80, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      _buildColorGridItem(setDialogState, 100, 60, 160, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      _buildColorGridItem(setDialogState, 200, 100, 150, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      _buildColorGridItem(setDialogState, 160, 100, 60, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      _buildColorGridItem(setDialogState, 180, 140, 100, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                      _buildColorGridItem(setDialogState, 240, 220, 200, (r, g, b) { tempR = r; tempG = g; tempB = b; }),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Fine-tune sliders
                  _buildDialogRGBSlider('Red', tempR, Colors.red, (v) {
                    setDialogState(() => tempR = v);
                  }),
                  _buildDialogRGBSlider('Green', tempG, Colors.green, (v) {
                    setDialogState(() => tempG = v);
                  }),
                  _buildDialogRGBSlider('Blue', tempB, Colors.blue, (v) {
                    setDialogState(() => tempB = v);
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: SapemoiTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _editableColors[index] = ColorInfo(
                    r: tempR,
                    g: tempG,
                    b: tempB,
                    pct: currentColor.pct,
                  );
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SapemoiTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildColorGridItem(StateSetter setDialogState, int r, int g, int b, Function(int, int, int) onSelect) {
    return GestureDetector(
      onTap: () {
        setDialogState(() => onSelect(r, g, b));
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color.fromRGBO(r, g, b, 1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: (r > 230 && g > 230 && b > 230) ? SapemoiTheme.border : Colors.transparent,
          ),
        ),
      ),
    );
  }
  
  Widget _buildDialogRGBSlider(String label, int value, Color color, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: SapemoiTheme.textSecondary),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: color,
                inactiveTrackColor: color.withOpacity(0.2),
                thumbColor: color,
                trackHeight: 4,
              ),
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: 255,
                onChanged: (v) => onChanged(v.toInt()),
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$value',
              style: TextStyle(fontSize: 11, color: SapemoiTheme.textMuted),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SapemoiTheme.surface,
        borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
        border: Border.all(color: SapemoiTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.repeat,
              label: 'Worn',
              value: '${widget.clothing.wearCount}x',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: SapemoiTheme.border,
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.calendar_today_outlined,
              label: 'Last worn',
              value: widget.clothing.lastWorn != null
                  ? _formatDate(widget.clothing.lastWorn!)
                  : 'Never',
            ),
          ),
          if (widget.clothing.estimatedValue != null) ...[
            Container(
              width: 1,
              height: 40,
              color: SapemoiTheme.border,
            ),
            Expanded(
              child: _buildStatItem(
                icon: Icons.sell_outlined,
                label: 'Value',
                value: '€${widget.clothing.estimatedValue!.toInt()}',
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: SapemoiTheme.primary, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: SapemoiTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: SapemoiTheme.textMuted,
          ),
        ),
      ],
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7}w ago';
    return '${diff.inDays ~/ 30}m ago';
  }
  
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SapemoiTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SapemoiTheme.radiusLg),
        ),
        title: Text(
          'Delete Item?',
          style: TextStyle(color: SapemoiTheme.textPrimary),
        ),
        content: Text(
          'This will permanently remove "${widget.clothing.name}" from your wardrobe.',
          style: TextStyle(color: SapemoiTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: SapemoiTheme.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}