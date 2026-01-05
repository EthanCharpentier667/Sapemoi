import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../auth_manager.dart';
import '../user_model.dart';
import '../db_manager.dart';
import '../network_manager.dart';
import '../models.dart';
import '../recommendation_engine.dart';
import '../theme.dart';
import 'create_post_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<Clothing> _clothes = [];
  double? _wardrobeValue;
  bool _loadingValue = false;
  StyleProfile? _storedStyle;
  bool _loadingStyle = false;
  bool _loadingUser = true;
  UserModel? _userModel;
  List<OutfitPost> _myPosts = [];
  List<Map<String, dynamic>> _recentOutfits = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loadingUser = true);
    final userModel = await AuthManager().getLocalUser();
    if (userModel == null) {
      setState(() => _loadingUser = false);
      return;
    }

    final results = await Future.wait([
      DBManager().getAllClothes(userModel.uid),
      DBManager().getTotalWardrobeValue(userModel.uid),
      DBManager().getUserStyle(userModel.uid),
      NetworkManager().getUserPostsRemote(userModel.uid, limit: 20),
      DBManager().getRecentOutfits(userModel.uid, limit: 5),
    ]);

    final clothes = results[0] as List<Clothing>;
    final total = results[1] as double;
    final stored = results[2] as StyleProfile?;
    final posts = results[3] as List<OutfitPost>;
    final recent = results[4] as List<Map<String, dynamic>>;

    setState(() {
      _userModel = userModel;
      _clothes = clothes;
      _storedStyle = stored;
      _myPosts = posts;
      _recentOutfits = recent;
      if (total > 0) {
        _wardrobeValue = total;
      }
      _loadingUser = false;
    });
  }

  Future<void> _estimateStyle() async {
    final userModel = await AuthManager().getLocalUser();
    if (userModel == null) return;

    setState(() => _loadingStyle = true);
    try {
      final clothes = await DBManager().getAllClothes(userModel.uid);
      final profile = await StyleProfile.fromClothes(clothes);
      await DBManager().saveUserStyle(userModel.uid, profile);
      RecommendationEngine.clearCache();
      setState(() {
        _storedStyle = profile;
        _loadingStyle = false;
      });
    } catch (e) {
      setState(() => _loadingStyle = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error estimating style: $e')));
      }
    }
  }

  Future<void> _estimateWardrobeValue() async {
    final userModel = await AuthManager().getLocalUser();
    if (userModel == null) return;

    setState(() => _loadingValue = true);

    try {
      final unvaluedIds = await DBManager().getUnvaluedClothingIds(userModel.uid);
      
      if (unvaluedIds.isNotEmpty) {
        final unvaluedItems = _clothes.where((c) => unvaluedIds.contains(c.id)).map((c) => {
          'id': c.id,
          'brand': c.brand,
          'product': c.productName,
          'type': c.type,
          'specificType': c.specificType,
        }).toList();

        final result = await NetworkManager().estimateWardrobeValue(unvaluedItems);
        final breakdown = result['breakdown'] as List<dynamic>;
        
        for (var i = 0; i < breakdown.length; i++) {
          final item = breakdown[i] as Map<String, dynamic>;
          final estimatedValue = (item['estimatedValue'] as num).toDouble();
          final clothingId = unvaluedItems[i]['id'] as int;
          await DBManager().updateEstimatedValue(clothingId, estimatedValue);
        }
      }
      
      final total = await DBManager().getTotalWardrobeValue(userModel.uid);
      await _loadData();
      
      setState(() {
        _wardrobeValue = total;
        _loadingValue = false;
      });
    } catch (e) {
      setState(() => _loadingValue = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error estimating value: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userModel = _userModel;

    if (_loadingUser) {
      return Scaffold(
        backgroundColor: SapemoiTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: SapemoiTheme.primary),
        ),
      );
    }

    if (userModel == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      });
      return Scaffold(backgroundColor: SapemoiTheme.background);
    }

    final mostWorn = [..._clothes]..sort((a, b) => b.wearCount.compareTo(a.wearCount));
    final leastWorn = [..._clothes]..sort((a, b) => a.wearCount.compareTo(b.wearCount));

    return Scaffold(
      backgroundColor: SapemoiTheme.background,
      body: RefreshIndicator(
        color: SapemoiTheme.primary,
        backgroundColor: SapemoiTheme.surface,
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // Header avec photo de profil
            SliverToBoxAdapter(
              child: _buildProfileHeader(userModel),
            ),
            
            // Stats rapides
            SliverToBoxAdapter(
              child: _buildQuickStats(),
            ),
            
            // Wardrobe Value Card
            SliverToBoxAdapter(
              child: _buildWardrobeValueCard(),
            ),
            
            // Style Card
            SliverToBoxAdapter(
              child: _buildStyleCard(),
            ),
            
            // Most Worn
            SliverToBoxAdapter(
              child: _buildMostWornSection(mostWorn),
            ),
            
            // Least Worn
            SliverToBoxAdapter(
              child: _buildLeastWornSection(leastWorn),
            ),
            
            // My Posts
            SliverToBoxAdapter(
              child: _buildPostsSection(),
            ),
            
            // Account Info
            SliverToBoxAdapter(
              child: _buildAccountInfo(userModel),
            ),
            
            // Actions
            SliverToBoxAdapter(
              child: _buildActions(),
            ),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserModel userModel) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24,
        right: 24,
        bottom: 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SapemoiTheme.primary.withOpacity(0.15),
            SapemoiTheme.background,
          ],
        ),
      ),
      child: Column(
        children: [
          // Avatar avec glow
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: SapemoiTheme.primary.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SapemoiTheme.primaryGradient,
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: SapemoiTheme.surface,
                backgroundImage: userModel.photoURL != null
                  ? NetworkImage(userModel.photoURL!)
                  : null,
                child: userModel.photoURL == null
                  ? Icon(Icons.person, size: 50, color: SapemoiTheme.textMuted)
                  : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Nom
          Text(
            userModel.displayName ?? 'Anonymous',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: SapemoiTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          
          // Email
          Text(
            userModel.email,
            style: TextStyle(
              fontSize: 14,
              color: SapemoiTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.checkroom,
              value: '${_clothes.length}',
              label: 'Items',
              color: SapemoiTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.photo_library,
              value: '${_myPosts.length}',
              label: 'Posts',
              color: SapemoiTheme.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.history,
              value: '${_recentOutfits.length}',
              label: 'Outfits',
              color: const Color(0xFF22C55E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: SapemoiTheme.surface,
        borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
        border: Border.all(color: SapemoiTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: SapemoiTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: SapemoiTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWardrobeValueCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF22C55E).withOpacity(0.15),
              SapemoiTheme.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(SapemoiTheme.radiusLg),
          border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(SapemoiTheme.radiusSm),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: Color(0xFF22C55E), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Wardrobe Value',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: SapemoiTheme.textPrimary,
                      ),
                    ),
                  ),
                  _buildActionButton(
                    onPressed: _loadingValue ? null : _estimateWardrobeValue,
                    label: _wardrobeValue == null ? 'Estimate' : 'Refresh',
                    isLoading: _loadingValue,
                    color: const Color(0xFF22C55E),
                  ),
                ],
              ),
              if (_wardrobeValue != null) ...[
                const SizedBox(height: 20),
                Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF10B981)],
                    ).createShader(bounds),
                    child: Text(
                      '\$${_wardrobeValue!.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Based on ${_clothes.length} items',
                    style: TextStyle(
                      fontSize: 13,
                      color: SapemoiTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyleCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              SapemoiTheme.primary.withOpacity(0.15),
              SapemoiTheme.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(SapemoiTheme.radiusLg),
          border: Border.all(color: SapemoiTheme.primary.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SapemoiTheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(SapemoiTheme.radiusSm),
                    ),
                    child: Icon(Icons.palette, color: SapemoiTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _storedStyle != null ? 'Your Style' : 'Style Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: SapemoiTheme.textPrimary,
                          ),
                        ),
                        if (_storedStyle != null)
                          Text(
                            _capitalizeFirst(_storedStyle!.styleType),
                            style: TextStyle(
                              fontSize: 14,
                              color: SapemoiTheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildActionButton(
                    onPressed: _loadingStyle ? null : _estimateStyle,
                    label: _storedStyle == null ? 'Analyze' : 'Update',
                    isLoading: _loadingStyle,
                    color: SapemoiTheme.primary,
                  ),
                ],
              ),
              if (_storedStyle != null && _storedStyle!.topBrands.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _storedStyle!.topBrands.take(4).map((brand) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: SapemoiTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
                        border: Border.all(color: SapemoiTheme.border),
                      ),
                      child: Text(
                        _capitalizeFirst(brand),
                        style: TextStyle(
                          fontSize: 12,
                          color: SapemoiTheme.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String label,
    required bool isLoading,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          : Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
      ),
    );
  }

  Widget _buildMostWornSection(List<Clothing> mostWorn) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: const Color(0xFFFBBF24), size: 24),
              const SizedBox(width: 8),
              Text(
                'Most Worn',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: SapemoiTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (mostWorn.isEmpty)
            _buildEmptySection('No items worn yet')
          else
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: mostWorn.take(5).length,
                itemBuilder: (context, index) {
                  final item = mostWorn[index];
                  return _buildWornItemCard(
                    item,
                    '${item.wearCount}x',
                    const Color(0xFFFBBF24),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeastWornSection(List<Clothing> leastWorn) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sell_outlined, color: SapemoiTheme.primaryLight, size: 24),
              const SizedBox(width: 8),
              Text(
                'Consider Selling',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: SapemoiTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Items that could find a new home',
            style: TextStyle(
              fontSize: 13,
              color: SapemoiTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          if (leastWorn.isEmpty)
            _buildEmptySection('No items to show')
          else
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: leastWorn.take(5).length,
                itemBuilder: (context, index) {
                  final item = leastWorn[index];
                  return _buildWornItemCard(
                    item,
                    item.wearCount == 0 ? 'Never' : '${item.wearCount}x',
                    SapemoiTheme.primaryLight,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWornItemCard(Clothing item, String label, Color accentColor) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
              border: Border.all(color: accentColor.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd - 2),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
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
                  child: Icon(Icons.image, color: SapemoiTheme.textMuted),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection(String message) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: SapemoiTheme.surface,
        borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
        border: Border.all(color: SapemoiTheme.border),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: SapemoiTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildPostsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library_rounded, color: SapemoiTheme.accent, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'My Posts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: SapemoiTheme.textPrimary,
                  ),
                ),
              ),
              if (_recentOutfits.isNotEmpty)
                GestureDetector(
                  onTap: _showPostLastOutfitDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: SapemoiTheme.accentGradient,
                      borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
                      boxShadow: [SapemoiTheme.shadowGlow(SapemoiTheme.accent)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_a_photo, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        const Text(
                          'Post Last',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_myPosts.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: SapemoiTheme.surface,
                borderRadius: BorderRadius.circular(SapemoiTheme.radiusLg),
                border: Border.all(color: SapemoiTheme.border),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 48,
                    color: SapemoiTheme.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No posts yet',
                    style: TextStyle(
                      color: SapemoiTheme.textMuted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share your outfits with the community',
                    style: TextStyle(
                      color: SapemoiTheme.textMuted.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _myPosts.length,
                itemBuilder: (context, index) {
                  return _buildPostThumbnail(_myPosts[index]);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPostThumbnail(OutfitPost post) {
    return GestureDetector(
      onLongPress: () => _showDeletePostDialog(post),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
                  border: Border.all(color: SapemoiTheme.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd - 1),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: post.imageUrl,
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
                          child: Icon(Icons.error, color: SapemoiTheme.textMuted),
                        ),
                      ),
                      // Delete button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _showDeletePostDialog(post),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                      // Likes badge
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: SapemoiTheme.background.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.favorite, color: SapemoiTheme.accent, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${post.likes}',
                                style: TextStyle(
                                  color: SapemoiTheme.textPrimary,
                                  fontSize: 11,
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
              ),
            ),
            const SizedBox(height: 8),
            Text(
              post.description.isEmpty ? 'No caption' : post.description,
              style: TextStyle(
                fontSize: 12,
                color: SapemoiTheme.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfo(UserModel userModel) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: SapemoiTheme.surface,
          borderRadius: BorderRadius.circular(SapemoiTheme.radiusLg),
          border: Border.all(color: SapemoiTheme.border),
        ),
        child: Column(
          children: [
            _buildInfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: userModel.email,
            ),
            Divider(color: SapemoiTheme.border, height: 1),
            _buildInfoRow(
              icon: Icons.fingerprint,
              label: 'User ID',
              value: '${userModel.uid.substring(0, 12)}...',
            ),
            Divider(color: SapemoiTheme.border, height: 1),
            _buildInfoRow(
              icon: Icons.verified_outlined,
              label: 'Email Verified',
              value: (FirebaseAuth.instance.currentUser?.emailVerified ?? false) ? 'Yes' : 'No',
              valueColor: (FirebaseAuth.instance.currentUser?.emailVerified ?? false)
                ? const Color(0xFF22C55E)
                : SapemoiTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: SapemoiTheme.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: SapemoiTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? SapemoiTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (_recentOutfits.isNotEmpty)
            GestureDetector(
              onTap: _showClearWornOutfitsDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: SapemoiTheme.surface,
                  borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
                  border: Border.all(color: SapemoiTheme.primaryMuted.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_sweep, color: SapemoiTheme.primaryLight, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Clear Worn Outfits History',
                      style: TextStyle(
                        color: SapemoiTheme.primaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              RecommendationEngine.clearCache();
              await AuthManager().signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                borderRadius: BorderRadius.circular(SapemoiTheme.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  void _showDeletePostDialog(OutfitPost post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SapemoiTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SapemoiTheme.radiusLg),
        ),
        title: Text(
          'Delete Post?',
          style: TextStyle(color: SapemoiTheme.textPrimary),
        ),
        content: Text(
          'This action cannot be undone.',
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
            onPressed: () async {
              Navigator.pop(context);
              final userModel = await AuthManager().getLocalUser();
              if (userModel != null) {
                await DBManager().deleteOutfitPost(post.id, userModel.uid);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Post deleted'),
                      backgroundColor: SapemoiTheme.surface,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SapemoiTheme.radiusSm),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showPostLastOutfitDialog() {
    if (_recentOutfits.isEmpty) return;

    final lastOutfit = _recentOutfits.first;
    final clothingIds = (lastOutfit['clothing_ids'] as String?)?.split(',').map((id) => int.parse(id)).toList() ?? [];
    final outfitItems = _clothes.where((c) => clothingIds.contains(c.id)).toList();

    if (outfitItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No outfit items found'),
          backgroundColor: SapemoiTheme.surface,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SapemoiTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SapemoiTheme.radiusLg),
        ),
        title: Text(
          'Post Last Worn Outfit?',
          style: TextStyle(color: SapemoiTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your last worn outfit:',
              style: TextStyle(color: SapemoiTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: outfitItems.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SapemoiTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
                    border: Border.all(color: SapemoiTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: NetworkImage(item.imageUrl),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.name,
                        style: TextStyle(
                          color: SapemoiTheme.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: SapemoiTheme.textMuted),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreatePostPage(outfitItems: outfitItems),
                ),
              ).then((_) => _loadData());
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

  void _showClearWornOutfitsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SapemoiTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SapemoiTheme.radiusLg),
        ),
        title: Text(
          'Clear Worn Outfits?',
          style: TextStyle(color: SapemoiTheme.textPrimary),
        ),
        content: Text(
          'This will delete all ${_recentOutfits.length} worn outfit records from your history. This action cannot be undone.',
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
            onPressed: () async {
              Navigator.pop(context);
              final userModel = await AuthManager().getLocalUser();
              if (userModel != null) {
                await DBManager().clearWornOutfits(userModel.uid);
                await _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('✨ Worn outfits history cleared'),
                      backgroundColor: SapemoiTheme.surface,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SapemoiTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SapemoiTheme.radiusSm),
              ),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
