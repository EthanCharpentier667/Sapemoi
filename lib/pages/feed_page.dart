import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models.dart';
import '../db_manager.dart';
import '../auth_manager.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final PageController _pageController = PageController();
  List<OutfitPost> _posts = [];
  bool _isLoading = true;
  int _currentIndex = 0;
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_posts.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.style_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No outfits yet',
                style: TextStyle(fontSize: 20, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first to share your style!',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _posts.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
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
          CachedNetworkImage(
            imageUrl: post.imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => Container(
              color: Colors.black,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.black,
              child: const Icon(Icons.error, color: Colors.white),
            ),
          ),
          
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.5, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Container(
                  color: Colors.black.withOpacity(0.3),
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.purple,
                        backgroundImage: post.photoURL != null
                            ? CachedNetworkImageProvider(post.photoURL!)
                            : null,
                        child: post.photoURL == null
                            ? Text(
                                post.username[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
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
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 3,
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatTime(post.createdAt),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),

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
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: post.clothingItems.map((item) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getIconForType(item.type),
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${item.brand} - ${item.name}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
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
              ],
            ),
          ),
          
          Positioned(
            right: 12,
            bottom: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                  label: _formatCount(post.likes),
                  color: post.isLiked ? Colors.red : Colors.white,
                  onTap: () => _toggleLike(post),
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  icon: Icons.comment,
                  label: _formatCount(post.comments),
                  color: Colors.white,
                  onTap: () {
                    // TODO: Ouvrir les commentaires
                  },
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  icon: Icons.share,
                  label: 'Share',
                  color: Colors.white,
                  onTap: () {
                    // TODO: Partager
                  },
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 2,
                  color: Colors.black,
                ),
              ],
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
      case 'top':
        return Icons.dry_cleaning;
      case 'bottom':
        return Icons.shopping_bag;
      case 'footwear':
        return Icons.sports_soccer;
      case 'headwear':
        return Icons.sports_baseball;
      case 'outerwear':
        return Icons.checkroom;
      case 'accessory':
        return Icons.watch;
      default:
        return Icons.checkroom;
    }
  }
}
