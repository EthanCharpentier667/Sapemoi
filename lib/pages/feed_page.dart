import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models.dart';
import '../db_manager.dart';
import '../auth_manager.dart';
import '../theme.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final PageController _pageController = PageController();
  List<OutfitPost> _posts = [];
  bool _isLoading = true;
  final Map<int, bool> _expandedDescriptions = {};

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    try {
      final userModel = await AuthManager().getLocalUser();
      if (userModel == null) return;
      
      final posts = await DBManager().getFeedPosts(userModel.uid);
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading feed: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(OutfitPost post) async {
    try {
      final userModel = await AuthManager().getLocalUser();
      if (userModel == null) return;

      await DBManager().toggleLikePost(post.id, userModel.uid);
      
      setState(() {
        post.isLiked = !post.isLiked;
        post.likes += post.isLiked ? 1 : -1;
      });
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: SapemoiTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: SapemoiTheme.primary),
        ),
      );
    }

    if (_posts.isEmpty) {
      return Scaffold(
        backgroundColor: SapemoiTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: SapemoiTheme.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.explore_outlined,
                  size: 56,
                  color: SapemoiTheme.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No outfits yet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: SapemoiTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Be the first to share your style!',
                style: TextStyle(color: SapemoiTheme.textMuted),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadFeed,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SapemoiTheme.background,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _posts.length,
        onPageChanged: (index) {
          setState(() {
            _expandedDescriptions.clear();
          });
        },
        itemBuilder: (context, index) {
          return _buildPostCard(_posts[index]);
        },
      ),
    );
  }

  Widget _buildPostCard(OutfitPost post) {
    return GestureDetector(
      onDoubleTap: () => _toggleLike(post),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          CachedNetworkImage(
            imageUrl: post.imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => Container(
              color: SapemoiTheme.background,
              child: const Center(
                child: CircularProgressIndicator(color: SapemoiTheme.primary),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: SapemoiTheme.background,
              child: const Icon(Icons.error, color: SapemoiTheme.textMuted),
            ),
          ),
          
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
                stops: const [0.0, 0.2, 0.6, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: SapemoiTheme.primary,
                            width: 2,
                          ),
                          boxShadow: [SapemoiTheme.shadowGlow(SapemoiTheme.primary)],
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: SapemoiTheme.surfaceLight,
                          backgroundImage: post.photoURL != null
                              ? CachedNetworkImageProvider(post.photoURL!)
                              : null,
                          child: post.photoURL == null
                              ? Text(
                                  post.username[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: SapemoiTheme.primary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatTime(post.createdAt),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: SapemoiTheme.surface.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.checkroom, size: 14, color: SapemoiTheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${post.clothingItems.length}',
                              style: const TextStyle(
                                color: SapemoiTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),

                // Bottom content
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (post.description.isNotEmpty) ...[
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _expandedDescriptions[post.id] = !(_expandedDescriptions[post.id] ?? false);
                            });
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.description,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                maxLines: _expandedDescriptions[post.id] ?? false ? null : 2,
                                overflow: _expandedDescriptions[post.id] ?? false 
                                    ? TextOverflow.visible 
                                    : TextOverflow.ellipsis,
                              ),
                              if (post.description.length > 80 && !(_expandedDescriptions[post.id] ?? false))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '...more',
                                    style: TextStyle(
                                      color: SapemoiTheme.primary.withOpacity(0.9),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Tags
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: post.clothingItems.map((item) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: SapemoiTheme.surface.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(SapemoiTheme.radiusFull),
                              border: Border.all(
                                color: SapemoiTheme.border.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getIconForType(item.type),
                                  size: 14,
                                  color: SapemoiTheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.brand,
                                  style: const TextStyle(
                                    color: SapemoiTheme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              
                // Bottom padding for nav bar
                const SizedBox(height: 80),
              ],
            ),
          ),
          
          // Action buttons
          Positioned(
            right: 12,
            bottom: 180,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                  label: _formatCount(post.likes),
                  color: post.isLiked ? SapemoiTheme.accent : Colors.white,
                  onTap: () => _toggleLike(post),
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: _formatCount(post.comments),
                  color: Colors.white,
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  icon: Icons.send_outlined,
                  label: 'Share',
                  color: Colors.white,
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  icon: Icons.bookmark_border,
                  label: 'Save',
                  color: Colors.white,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: SapemoiTheme.surface.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(color: SapemoiTheme.border.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inDays > 7) {
      return '${diff.inDays ~/ 7}w ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'top': return Icons.dry_cleaning;
      case 'bottom': return Icons.straighten;
      case 'footwear': return Icons.directions_walk;
      case 'headwear': return Icons.face;
      case 'outerwear': return Icons.ac_unit;
      case 'accessory': return Icons.watch;
      default: return Icons.checkroom;
    }
  }
}
