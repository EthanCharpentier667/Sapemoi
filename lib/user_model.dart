import 'dart:convert';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final DateTime createdAt;
  final String? styleProfileJson;
  
  // Derived fields from styleProfile JSON
  String get styleType {
    if (styleProfileJson == null) return 'casual';
    try {
      final json = _parseJson(styleProfileJson!);
      return json['styleType'] as String? ?? 'casual';
    } catch (_) {
      return 'casual';
    }
  }
  
  List<String> get topBrands {
    if (styleProfileJson == null) return [];
    try {
      final json = _parseJson(styleProfileJson!);
      final brands = json['topBrands'];
      if (brands is List) return brands.map((e) => e.toString()).toList();
      return [];
    } catch (_) {
      return [];
    }
  }
  
  List<String> get topTypes {
    if (styleProfileJson == null) return [];
    try {
      final json = _parseJson(styleProfileJson!);
      final types = json['topTypes'];
      if (types is List) return types.map((e) => e.toString()).toList();
      return [];
    } catch (_) {
      return [];
    }
  }
  
  static Map<String, dynamic> _parseJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    required this.createdAt,
    this.styleProfileJson,
  });

  Map<String, dynamic> toMap() {
    final map = {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
    if (styleProfileJson != null) {
      map['styleProfile'] = styleProfileJson;
    }
    return map;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // createdAt may be sent as int (ms), string, ISO datetime, or null from API.
    final createdRaw = map['createdAt'] ?? map['createdat'];
    DateTime createdAt;
    try {
      if (createdRaw == null) {
        createdAt = DateTime.now();
      } else if (createdRaw is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(createdRaw);
      } else if (createdRaw is double) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(createdRaw.toInt());
      } else if (createdRaw is String) {
        final asInt = int.tryParse(createdRaw);
        if (asInt != null) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(asInt);
        } else {
          createdAt = DateTime.tryParse(createdRaw) ?? DateTime.now();
        }
      } else {
        createdAt = DateTime.now();
      }
    } catch (_) {
      createdAt = DateTime.now();
    }
    
    // styleProfile can be stored as TEXT (JSON string) in PostgreSQL
    final styleProfileRaw = map['styleProfile'] ?? map['styleprofile'];
    String? styleProfileJson;
    if (styleProfileRaw != null) {
      if (styleProfileRaw is String) {
        styleProfileJson = styleProfileRaw;
      } else if (styleProfileRaw is Map) {
        styleProfileJson = jsonEncode(styleProfileRaw);
      }
    }

    return UserModel(
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String? ?? map['displayname'] as String?,
      photoURL: map['photoURL'] as String? ?? map['photourl'] as String?,
      createdAt: createdAt,
      styleProfileJson: styleProfileJson,
    );
  }


}
