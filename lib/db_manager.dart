import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class DBManager {
  static final DBManager _instance = DBManager._internal();
  static Database? _database;

  factory DBManager() => _instance;

  DBManager._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'Sapemoi.db');

    print('✅ Database path: $path');

    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        uid TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        displayName TEXT,
        photoURL TEXT,
        createdAt INTEGER NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE clothing (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        name TEXT NOT NULL,
        imagePath TEXT NOT NULL,
        imageBase64 TEXT,
        type TEXT NOT NULL,
        specificType TEXT DEFAULT 'unknown',
        colors TEXT NOT NULL,
        brand TEXT DEFAULT 'unknown',
        productName TEXT DEFAULT 'unknown',
        createdAt INTEGER NOT NULL,
        wearCount INTEGER DEFAULT 0,
        lastWorn INTEGER,
        estimatedValue REAL,
        FOREIGN KEY (userId) REFERENCES users (uid) ON DELETE CASCADE
      )
    ''');
    
    await db.execute('''
      CREATE TABLE outfit_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        outfitItems TEXT NOT NULL,
        usedAt INTEGER NOT NULL,
        FOREIGN KEY (userId) REFERENCES users (uid) ON DELETE CASCADE
      )
    ''');
    print('✅ Tables created');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE clothing ADD COLUMN userId TEXT');
        print('✅ Migration: Added userId column');
      } catch (e) {
        print('⚠️ Migration error (might already exist): $e');
      }
      
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS users (
            uid TEXT PRIMARY KEY,
            email TEXT NOT NULL,
            displayName TEXT,
            photoURL TEXT,
            createdAt INTEGER NOT NULL
          )
        ''');
        print('✅ Migration: Created users table');
      } catch (e) {
        print('⚠️ Migration error (might already exist): $e');
      }
    }
    
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE clothing ADD COLUMN specificType TEXT DEFAULT "unknown"');
        print('✅ Migration: Added specificType column');
      } catch (e) {
        print('⚠️ Migration error (might already exist): $e');
      }
    }
    
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE clothing ADD COLUMN wearCount INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE clothing ADD COLUMN lastWorn INTEGER');
        print('✅ Migration: Added wearCount and lastWorn columns');
      } catch (e) {
        print('⚠️ Migration error (might already exist): $e');
      }
      
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS outfit_usage (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            outfitItems TEXT NOT NULL,
            usedAt INTEGER NOT NULL,
            FOREIGN KEY (userId) REFERENCES users (uid) ON DELETE CASCADE
          )
        ''');
        print('✅ Migration: Created outfit_usage table');
      } catch (e) {
        print('⚠️ Migration error (might already exist): $e');
      }
    }
    
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE clothing ADD COLUMN estimatedValue REAL');
        print('✅ Migration: Added estimatedValue column');
      } catch (e) {
        print('⚠️ Migration error (might already exist): $e');
      }
    }
  }

  Future<int> addClothing(Clothing clothing, String userId) async {
    final db = await database;
    final map = clothing.toMap();
    map['userId'] = userId;
    
    map.remove('id');
    
    final id = await db.insert('clothing', map);
    print('✅ Clothing added with ID: $id for user: $userId');
    return id;
  }

  Future<List<Clothing>> getAllClothes(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clothing',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'type, name',
    );

    final clothes = maps.map((map) => Clothing.fromMap(map)).toList();
    print('✅ Fetched ${clothes.length} clothing items for user: $userId');
    return clothes;
  }

  Future<bool> updateClothing(Clothing clothing) async {
    final db = await database;
    final count = await db.update(
      'clothing',
      clothing.toMap(),
      where: 'id = ?',
      whereArgs: [clothing.id],
    );
    print('✅ Clothing updated (ID: ${clothing.id})');
    return count > 0;
  }

  Future<bool> deleteClothing(int id) async {
    final db = await database;
    final count = await db.delete(
      'clothing',
      where: 'id = ?',
      whereArgs: [id],
    );
    print('✅ Clothing deleted with ID: $id');
    return count > 0;
  }
  
  Future<void> markOutfitAsUsed(List<int> clothingIds, String userId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert('outfit_usage', {
      'userId': userId,
      'outfitItems': clothingIds.join(','),
      'usedAt': now,
    });
    
    for (final id in clothingIds) {
      await db.execute('''
        UPDATE clothing 
        SET wearCount = wearCount + 1, lastWorn = ? 
        WHERE id = ?
      ''', [now, id]);
    }
    
    print('✅ Outfit marked as used with ${clothingIds.length} items');
  }
  
  Future<List<Map<String, dynamic>>> getWearFrequencyStats(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> stats = await db.query(
      'clothing',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'wearCount DESC',
    );
    return stats;
  }
  
  Future<List<Map<String, dynamic>>> getRecentOutfits(String userId, {int limit = 10}) async {
    final db = await database;
    final List<Map<String, dynamic>> outfits = await db.query(
      'outfit_usage',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'usedAt DESC',
      limit: limit,
    );
    return outfits;
  }
  
  Future<void> updateEstimatedValue(int clothingId, double value) async {
    final db = await database;
    await db.update(
      'clothing',
      {'estimatedValue': value},
      where: 'id = ?',
      whereArgs: [clothingId],
    );
    print('✅ Updated estimated value for clothing ID: $clothingId to \$$value');
  }
  
  Future<double> getTotalWardrobeValue(String userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(estimatedValue) as total FROM clothing WHERE userId = ? AND estimatedValue IS NOT NULL',
      [userId],
    );
    final total = result.first['total'] as double?;
    return total ?? 0.0;
  }
  
  Future<List<int>> getUnvaluedClothingIds(String userId) async {
    final db = await database;
    final result = await db.query(
      'clothing',
      columns: ['id'],
      where: 'userId = ? AND estimatedValue IS NULL',
      whereArgs: [userId],
    );
    return result.map((row) => row['id'] as int).toList();
  }
}
