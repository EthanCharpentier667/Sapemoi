class Clothing {
  int id;
  String name;
  String imagePath;
  String? imageBase64;
  String type;
  String specificType;
  List<ColorInfo> colors;
  String brand;
  String productName;
  DateTime createdAt;
  int wearCount;
  DateTime? lastWorn;
  double? estimatedValue;

  Clothing({
    required this.id,
    required this.name,
    required this.imagePath,
    this.imageBase64,
    required this.type,
    this.specificType = 'unknown',
    required this.colors,
    this.brand = 'unknown',
    this.productName = 'unknown',
    required this.createdAt,
    this.wearCount = 0,
    this.lastWorn,
    this.estimatedValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'imageBase64': imageBase64,
      'type': type,
      'specificType': specificType,
      'colors': colors.map((c) => '${c.r},${c.g},${c.b},${c.pct}').join(';'),
      'brand': brand,
      'productName': productName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'wearCount': wearCount,
      'lastWorn': lastWorn?.millisecondsSinceEpoch,
      'estimatedValue': estimatedValue,
    };
  }

  factory Clothing.fromMap(Map<String, dynamic> map) {
    final colorString = map['colors'] as String;
    final colorParts = colorString.split(';');
    final colors = colorParts.map((part) {
      final cleanedPart = part.replaceAll('%', '').trim();
      final values = cleanedPart.split(',').map((e) {
        final cleaned = e.trim();
        return int.tryParse(cleaned) ?? 0;
      }).toList();
      
      if (values.length == 4) {
        return ColorInfo(r: values[0], g: values[1], b: values[2], pct: values[3]);
      }
      return ColorInfo(r: 0, g: 0, b: 0, pct: 0);
    }).where((c) => c.pct > 0).toList();

    return Clothing(
      id: map['id'] as int,
      name: map['name'] as String,
      imagePath: map['imagePath'] as String,
      imageBase64: map['imageBase64'] as String?,
      type: map['type'] as String,
      specificType: map['specificType'] as String? ?? 'unknown',
      colors: colors.isEmpty ? [ColorInfo(r: 128, g: 128, b: 128, pct: 100)] : colors,
      brand: map['brand'] as String? ?? 'unknown',
      productName: map['productName'] as String? ?? 'unknown',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      wearCount: map['wearCount'] as int? ?? 0,
      lastWorn: map['lastWorn'] != null ? DateTime.fromMillisecondsSinceEpoch(map['lastWorn'] as int) : null,
      estimatedValue: map['estimatedValue'] as double?,
    );
  }
}

class ColorInfo {
  final int r;
  final int g;
  final int b;
  final int pct;

  ColorInfo({
    required this.r,
    required this.g,
    required this.b,
    required this.pct,
  });
}

class OutfitResult {
  final bool valid;
  final double score;
  final List<ColorClash> clashes;

  OutfitResult({
    required this.valid,
    required this.score,
    required this.clashes,
  });
}

class ColorClash {
  final String type1;
  final ColorInfo color1;
  final String type2;
  final ColorInfo color2;
  final double score;

  ColorClash({
    required this.type1,
    required this.color1,
    required this.type2,
    required this.color2,
    required this.score,
  });
}
