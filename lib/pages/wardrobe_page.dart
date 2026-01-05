import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models.dart';
import '../theme.dart';

class WardrobePage extends StatefulWidget {
  final List<Clothing> clothes;
  final String searchText;
  final Function(String) onSearchChanged;
  final VoidCallback onAddPressed;
  final Function(Clothing) onClothingTap;

  const WardrobePage({
    super.key,
    required this.clothes,
    required this.searchText,
    required this.onSearchChanged,
    required this.onAddPressed,
    required this.onClothingTap,
  });

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  String? _selectedFilter;
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Clothing> get _filteredClothes {
    var filtered = widget.clothes;
    
    if (_selectedFilter != null) {
      filtered = filtered.where((c) => c.type == _selectedFilter).toList();
    }
    
    if (widget.searchText.isNotEmpty) {
      final query = widget.searchText.toLowerCase();
      filtered = filtered.where((c) {
        return c.name.toLowerCase().contains(query) ||
               c.type.toLowerCase().contains(query) ||
               c.brand.toLowerCase().contains(query) ||
               c.productName.toLowerCase().contains(query);
      }).toList();
    }
    
    return filtered;
  }

  Set<String> get _availableTypes => widget.clothes.map((c) => c.type).toSet();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SapemoiTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_showSearch) _buildSearchBar(),
            _buildFilters(),
            Expanded(child: _buildClothesGrid()),
          ],
        ),
      ),
      floatingActionButton: _buildAddButton(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => SapemoiTheme.accentGradient.createShader(bounds),
                child: const Text(
                  'Sapemoi',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              Text(
                '${widget.clothes.length} items',
                style: const TextStyle(fontSize: 13, color: SapemoiTheme.textMuted),
              ),
            ],
          ),
          const Spacer(),
          _buildIconButton(
            icon: _showSearch ? Icons.close : Icons.search,
            onTap: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  widget.onSearchChanged('');
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: SapemoiTheme.surfaceLight,
          borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
          border: Border.all(color: SapemoiTheme.border.withOpacity(0.5)),
        ),
        child: Icon(icon, color: SapemoiTheme.textSecondary, size: 20),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: TextField(
        controller: _searchController,
        onChanged: widget.onSearchChanged,
        autofocus: true,
        style: const TextStyle(color: SapemoiTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by name, brand, type...',
          prefixIcon: const Icon(Icons.search, color: SapemoiTheme.textMuted),
          suffixIcon: widget.searchText.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: SapemoiTheme.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    widget.onSearchChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip(null, 'All'),
          ..._availableTypes.map((type) => _buildFilterChip(type, type)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String? type, String label) {
    final isSelected = _selectedFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = type),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: isSelected ? SapemoiTheme.primaryGradient : null,
              color: isSelected ? null : SapemoiTheme.surfaceLight,
              borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
              border: Border.all(color: isSelected ? Colors.transparent : SapemoiTheme.border.withOpacity(0.5)),
              boxShadow: isSelected ? [SapemoiTheme.shadowGlow(SapemoiTheme.primary)] : null,
            ),
            child: Text(
              _capitalizeFirst(label),
              style: TextStyle(
                color: isSelected ? Colors.white : SapemoiTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClothesGrid() {
    final filtered = _filteredClothes;
    if (filtered.isEmpty) return _buildEmptyState();

    final grouped = <String, List<Clothing>>{};
    for (final item in filtered) {
      grouped.putIfAbsent(item.type, () => []).add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        final type = grouped.keys.elementAt(index);
        final items = grouped[type]!;
        return _buildTypeSection(type, items);
      },
    );
  }

  Widget _buildTypeSection(String type, List<Clothing> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SapemoiTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(SapemoiTheme.radiusSm),
                ),
                child: Icon(_getTypeIcon(type), color: SapemoiTheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                _capitalizeFirst(type),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: SapemoiTheme.textPrimary),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: SapemoiTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
                ),
                child: Text('${items.length}', style: const TextStyle(fontSize: 12, color: SapemoiTheme.textMuted, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _buildClothingCard(items[i]),
        ),
      ],
    );
  }

  Widget _buildClothingCard(Clothing item) {
    return GestureDetector(
      onTap: () => widget.onClothingTap(item),
      child: Container(
        decoration: BoxDecoration(
          color: SapemoiTheme.surface,
          borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
          border: Border.all(color: SapemoiTheme.border.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(SapemoiTheme.radiusMd - 1)),
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: SapemoiTheme.surfaceLight,
                        child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: SapemoiTheme.primary))),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: SapemoiTheme.surfaceLight,
                        child: const Icon(Icons.checkroom, color: SapemoiTheme.textMuted, size: 40),
                      ),
                    ),
                  ),
                  if (item.wearCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: SapemoiTheme.surface.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.repeat, size: 12, color: SapemoiTheme.primary),
                            const SizedBox(width: 4),
                            Text('${item.wearCount}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SapemoiTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.brand.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: SapemoiTheme.primary, letterSpacing: 0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: SapemoiTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ...item.colors.take(4).map((color) => Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(color.r, color.g, color.b, 1),
                          shape: BoxShape.circle,
                          border: Border.all(color: SapemoiTheme.border, width: 1),
                        ),
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
        boxShadow: [SapemoiTheme.shadowGlow(SapemoiTheme.primary)],
      ),
      child: FloatingActionButton.extended(
        onPressed: widget.onAddPressed,
        backgroundColor: SapemoiTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add),
        label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w600)),
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
            decoration: const BoxDecoration(color: SapemoiTheme.surfaceLight, shape: BoxShape.circle),
            child: const Icon(Icons.checkroom_outlined, size: 48, color: SapemoiTheme.textMuted),
          ),
          const SizedBox(height: 20),
          const Text('No items found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: SapemoiTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('Add some clothes to your wardrobe', style: TextStyle(color: SapemoiTheme.textMuted)),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'top': return Icons.dry_cleaning;
      case 'bottom': return Icons.straighten;
      case 'footwear': return Icons.directions_walk;
      case 'outerwear': return Icons.ac_unit;
      case 'headwear': return Icons.face;
      case 'accessory': return Icons.watch;
      case 'sweater': return Icons.thermostat;
      default: return Icons.checkroom;
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
