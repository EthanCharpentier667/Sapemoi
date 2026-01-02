import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../auth_manager.dart';
import '../user_model.dart';
import '../db_manager.dart';
import '../network_manager.dart';
import '../models.dart';
import '../recommendation_engine.dart';
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
  bool _loadingPosts = false;
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (userModel == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold();
    }

    final mostWorn = [..._clothes]..sort((a, b) => b.wearCount.compareTo(a.wearCount));
    final leastWorn = [..._clothes]..sort((a, b) => a.wearCount.compareTo(b.wearCount));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 60,
              backgroundImage: userModel.photoURL != null
                ? NetworkImage(userModel.photoURL!)
                : null,
              child: userModel.photoURL == null
                ? const Icon(Icons.person, size: 60)
                : null,
            ),
            const SizedBox(height: 24),
            Text(
              userModel.displayName ?? 'Anonymous',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              userModel.email,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 40),
            
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.attach_money, color: Colors.green, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Wardrobe Value',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _loadingValue ? null : _estimateWardrobeValue,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                          child: _loadingValue
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(_wardrobeValue == null ? 'Estimate' : 'Re-estimate'),
                        ),
                      ],
                    ),
                    if (_wardrobeValue != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          '\$${_wardrobeValue!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Based on ${_clothes.length} items',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_storedStyle != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.palette, color: Colors.purple, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Style: ${_capitalizeFirst(_storedStyle!.styleType)}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_storedStyle!.topBrands.isNotEmpty)
                        Text('Favorite brands: ${_storedStyle!.topBrands.map((b) => _capitalizeFirst(b)).join(", ")}', style: TextStyle(color: Colors.grey[700])),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _loadingStyle ? null : _estimateStyle,
                        icon: _loadingStyle
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.style),
                        label: const Text('Re-estimate Style'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      ),
                      const Divider(height: 32),
                    ] else ...[
                      Row(
                        children: [
                          const Icon(Icons.palette, color: Colors.purple, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No style estimated yet',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _loadingStyle ? null : _estimateStyle,
                        icon: _loadingStyle
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.style),
                        label: const Text('Estimate Style'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      ),
                      const Divider(height: 32),
                    ],
                    const Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 32),
                        SizedBox(width: 12),
                        Text(
                          'Most Worn Items',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (mostWorn.isEmpty)
                      const Center(
                        child: Text('No items worn yet'),
                      )
                    else
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: mostWorn.take(5).length,
                          itemBuilder: (context, index) {
                            final item = mostWorn[index];
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                children: [
                                  Container(
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.amber, width: 2),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
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
                                            child: const Icon(Icons.image, size: 40),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.wearCount}x worn',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
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
              ),
            ),
            
            const SizedBox(height: 24),
            
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shopping_bag_outlined, color: Colors.orange, size: 32),
                        SizedBox(width: 12),
                        Text(
                          'Least Worn Items',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Consider selling these items',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (leastWorn.isEmpty)
                      const Center(
                        child: Text('No items to show'),
                      )
                    else
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: leastWorn.take(5).length,
                          itemBuilder: (context, index) {
                            final item = leastWorn[index];
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                children: [
                                  Container(
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.orange, width: 2),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
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
                                            child: const Icon(Icons.image, size: 40),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.wearCount == 0 ? 'Never worn' : '${item.wearCount}x worn',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
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
              ),
            ),
            
            const SizedBox(height: 24),
            
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.photo_library, color: Colors.purple, size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'My Posts',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_recentOutfits.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: () => _showPostLastOutfitDialog(),
                            icon: const Icon(Icons.add_a_photo, size: 18),
                            label: const Text('Post Last'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_myPosts.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'No posts yet',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _myPosts.length,
                          itemBuilder: (context, index) {
                            final post = _myPosts[index];
                            return _buildPostThumbnail(post);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.email,
                      label: 'Email',
                      value: userModel.email,
                    ),
                    const Divider(height: 32),
                    _buildInfoRow(
                      icon: Icons.badge,
                      label: 'User ID',
                      value: '${userModel.uid.substring(0, 12)}...',
                    ),
                    const Divider(height: 32),
                    _buildInfoRow(
                      icon: Icons.verified_user,
                      label: 'Email Verified',
                      value: (FirebaseAuth.instance.currentUser?.emailVerified ?? false) ? 'Yes' : 'No',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            if (_recentOutfits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: OutlinedButton.icon(
                  onPressed: () => _showClearWornOutfitsDialog(),
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Clear Worn Outfits History'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange, width: 2),
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
            
            ElevatedButton(
              onPressed: () async {
                RecommendationEngine.clearCache();
                await AuthManager().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Sign Out'),
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
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.purple),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: post.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _showDeletePostDialog(post),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite, color: Colors.red, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${post.likes}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              post.description.isEmpty ? 'No caption' : post.description,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeletePostDialog(OutfitPost post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
                    const SnackBar(content: Text('Post deleted')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
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
        const SnackBar(content: Text('No outfit items found')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Post Last Worn Outfit?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your last worn outfit:'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: outfitItems.map((item) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundImage: NetworkImage(item.imageUrl),
                  ),
                  label: Text(item.name),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
            icon: const Icon(Icons.send),
            label: const Text('Post It'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
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
        title: const Text('Clear Worn Outfits?'),
        content: Text(
          'This will delete all ${_recentOutfits.length} worn outfit records from your history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
                    const SnackBar(content: Text('✨ Worn outfits history cleared')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
