import 'models.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final DateTime createdAt;
  final String styleType;
  final List<String> topBrands;
  final List<String> topTypes;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    required this.createdAt,
    this.styleType = 'casual',
    this.topBrands = const [],
    this.topTypes = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'styleType': styleType,
      'topBrands': topBrands.join(','),
      'topTypes': topTypes.join(','),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String?,
      photoURL: map['photoURL'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      styleType: map['styleType'] as String? ?? 'casual',
      topBrands: map['topBrands'] != null 
        ? (map['topBrands'] as String).split(',').where((s) => s.isNotEmpty).toList()
        : [],
      topTypes: map['topTypes'] != null
        ? (map['topTypes'] as String).split(',').where((s) => s.isNotEmpty).toList()
        : [],
    );
  }

  Future<UserModel> updateFromClothes(List<Clothing> clothes) async {
    final profile = await StyleProfile.fromClothes(clothes);
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      photoURL: photoURL,
      createdAt: createdAt,
      styleType: profile.styleType,
      topBrands: profile.topBrands,
      topTypes: profile.topTypes,
    );
  }
}
