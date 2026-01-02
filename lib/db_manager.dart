import 'dart:convert';
import 'models.dart';
import 'network_manager.dart';
import 'recommendation_engine.dart';

class DBManager {
  static final DBManager _instance = DBManager._internal();
  factory DBManager() => _instance;
  DBManager._internal();

  final NetworkManager _net = NetworkManager();

  Future<int?> addClothing(Clothing clothing, String userId) async {
    final map = clothing.toMap();
    map['userId'] = userId;
    map.remove('id');
    final id = await _net.addClothingRemote(map);
    if (id != null) {
      try {
        RecommendationEngine.clearCache();
      } catch (_) {}
    }
    return id;
  }

  Future<List<Clothing>> getAllClothes(String userId) async {
    final rows = await _net.getAllClothingRemote(userId);
    return rows.map((r) => Clothing.fromMap(r)).toList();
  }

  Future<bool> updateClothing(Clothing clothing) async {
    final updated = await _net.updateClothingRemote(clothing.id, clothing.toMap());
    if (updated != null) {
      try {
        final userId = updated['userId'] as String?;
        if (userId != null) {
          final clothes = await getAllClothes(userId);
          final profile = await StyleProfile.fromClothes(clothes);
          await saveUserStyle(userId, profile);
          RecommendationEngine.clearCache();
        }
      } catch (_) {}
      return true;
    }
    return false;
  }

  Future<bool> deleteClothing(int id) async {
    return await _net.deleteClothingRemote(id);
  }

  Future<void> saveUserStyle(String uid, StyleProfile style) async {
    final encoded = json.encode(style.toMap());
    await _net.updateUserStyleProfile(uid, encoded);
  }

  Future<StyleProfile?> getUserStyle(String uid) async {
    final remote = await _net.getUserStyleRemote(uid);
    if (remote == null) return null;
    try {
      return StyleProfile.fromMap(remote);
    } catch (e) {
      print('⚠️ Failed to parse remote style profile: $e');
      return null;
    }
  }

  Future<void> markOutfitAsUsed(List<int> clothingIds, String userId) async {
    await _net.markOutfitUsedRemote(clothingIds, userId);
  }

  Future<List<Map<String, dynamic>>> getWearFrequencyStats(String userId) async {
    return await _net.getWearStatsRemote(userId);
  }

  Future<List<Map<String, dynamic>>> getRecentOutfits(String userId, {int limit = 10}) async {
    return await _net.getRecentOutfitsRemote(userId, limit: limit);
  }

  Future<void> updateEstimatedValue(int clothingId, double value) async {
    await _net.updateClothingValueRemote(clothingId, value);
  }

  Future<double> getTotalWardrobeValue(String userId) async {
    return await _net.getTotalWardrobeValueRemote(userId);
  }

  Future<List<int>> getUnvaluedClothingIds(String userId) async {
    return await _net.getUnvaluedClothingIdsRemote(userId);
  }

  // Feed social methods
  Future<int?> createOutfitPost({
    required String userId,
    required String imageUrl,
    required String description,
    required List<int> clothingIds,
  }) async {
    return await _net.createOutfitPostRemote(
      userId: userId,
      imageUrl: imageUrl,
      description: description,
      clothingIds: clothingIds,
    );
  }

  Future<List<OutfitPost>> getFeedPosts(String currentUserId, {int limit = 50}) async {
    return await _net.getFeedPostsRemote(currentUserId, limit: limit);
  }

  Future<void> toggleLikePost(int postId, String userId) async {
    await _net.toggleLikePostRemote(postId, userId);
  }

  Future<void> deleteOutfitPost(int postId, String userId) async {
    await _net.deleteOutfitPostRemote(postId, userId);
  }

  Future<void> clearWornOutfits(String userId) async {
    await _net.clearWornOutfitsRemote(userId);
  }
}