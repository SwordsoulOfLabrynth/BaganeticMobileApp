import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/pagoda_model.dart';
import '../models/trip_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/logger.dart';
import '../../core/utils/image_path_utils.dart';
import 'migrations/database_migration.dart';
import 'migrations/migration_v4.dart';
import 'migrations/migration_v5.dart';
import 'migrations/migration_v6.dart';
import 'migrations/migration_v7.dart';

class DatabaseService {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
  
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), AppConstants.dbName);
    
    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final List<DatabaseMigration> migrations = [
      MigrationToV4(),
      MigrationToV5(),
      MigrationToV6(),
      MigrationToV7(),
    ]..sort((a, b) => a.targetVersion.compareTo(b.targetVersion));

    for (final migration in migrations) {
      if (oldVersion < migration.targetVersion &&
          newVersion >= migration.targetVersion) {
        Logger.info('Applying database migration v${migration.targetVersion}');
        await migration.migrate(db);
      }
    }
  }
  
  Future<void> _onCreate(Database db, int version) async {
    // Pagodas table
    await db.execute('''
      CREATE TABLE ${AppConstants.tablePagodas} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        imageUrl TEXT NOT NULL,
        images TEXT,
        historicalInfo TEXT,
        architecturalStyle TEXT,
        yearBuilt INTEGER,
        legends TEXT,
        religiousImportance TEXT,
        preservationInfo TEXT,
        bestTimeToVisit TEXT,
        visitorLocation TEXT,
        openingHours TEXT,
        dressCode TEXT,
        entranceFee TEXT,
        photographyRules TEXT,
        height TEXT,
        finalWords TEXT,
        uniqueFeatures TEXT,
        isFavorite INTEGER DEFAULT 0
      )
    ''');
    
    // Trips table
    await db.execute('''
      CREATE TABLE ${AppConstants.tableTrips} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    
    // Trip stops table
    await db.execute('''
      CREATE TABLE ${AppConstants.tableTripStops} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tripId TEXT NOT NULL,
        pagodaId TEXT NOT NULL,
        pagodaName TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        orderIndex INTEGER NOT NULL,
        notes TEXT,
        distanceToNext REAL,
        FOREIGN KEY (tripId) REFERENCES ${AppConstants.tableTrips}(id) ON DELETE CASCADE
      )
    ''');
    
    // Favorites table
    await db.execute('''
      CREATE TABLE ${AppConstants.tableFavorites} (
        pagodaId TEXT PRIMARY KEY,
        addedAt TEXT NOT NULL
      )
    ''');
  }
  
  // Pagoda CRUD operations
  Future<int> insertPagoda(Pagoda pagoda) async {
    final db = await database;
    
    // Normalize image paths before saving
    final String normalizedImageUrl = ImagePathUtils.normalizeImagePath(pagoda.imageUrl);
    final List<String> normalizedImages = pagoda.images
        .map((img) => ImagePathUtils.normalizeImagePath(img))
        .toList();
    
    final String uniqueFeaturesJson = jsonEncode(
      pagoda.uniqueFeatures.map((feature) => feature.toJson()).toList(),
    );

    return await db.insert(
      AppConstants.tablePagodas,
      {
        ...pagoda.toJson(),
        'imageUrl': normalizedImageUrl,
        'images': normalizedImages.join(','),
        'uniqueFeatures': uniqueFeaturesJson,
        'isFavorite': pagoda.isFavorite ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<Pagoda>> getAllPagodas() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(AppConstants.tablePagodas);
    
    return List.generate(maps.length, (i) {
      // Normalize image path
      final String? imageUrl = maps[i]['imageUrl'] as String?;
      final String normalizedImageUrl = imageUrl != null 
          ? ImagePathUtils.normalizeImagePath(imageUrl)
          : '';
      
      // Normalize images list
      final String? imagesStr = maps[i]['images'] as String?;
      final List<String> normalizedImages = (imagesStr?.split(',') ?? [])
          .where((img) => img.isNotEmpty)
          .map((img) => ImagePathUtils.normalizeImagePath(img))
          .toList();

      final List<dynamic> uniqueFeatures =
          _decodeUniqueFeatures(maps[i]['uniqueFeatures'] as String?);
      
      return Pagoda.fromJson({
        ...maps[i],
        'imageUrl': normalizedImageUrl,
        'images': normalizedImages,
        'uniqueFeatures': uniqueFeatures,
        'isFavorite': maps[i]['isFavorite'] == 1,
      });
    });
  }
  
  Future<Pagoda?> getPagodaById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tablePagodas,
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) return null;
    
    // Normalize image path
    final String? imageUrl = maps.first['imageUrl'] as String?;
    final String normalizedImageUrl = imageUrl != null 
        ? ImagePathUtils.normalizeImagePath(imageUrl)
        : '';
    
    // Normalize images list
    final String? imagesStr = maps.first['images'] as String?;
    final List<String> normalizedImages = (imagesStr?.split(',') ?? [])
        .where((img) => img.isNotEmpty)
        .map((img) => ImagePathUtils.normalizeImagePath(img))
        .toList();

    final List<dynamic> uniqueFeatures =
        _decodeUniqueFeatures(maps.first['uniqueFeatures'] as String?);
    
    return Pagoda.fromJson({
      ...maps.first,
      'imageUrl': normalizedImageUrl,
      'images': normalizedImages,
      'uniqueFeatures': uniqueFeatures,
      'isFavorite': maps.first['isFavorite'] == 1,
    });
  }
  
  Future<List<Pagoda>> searchPagodas(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tablePagodas,
      where: 'name LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    
    return List.generate(maps.length, (i) {
      // Normalize image path
      final String? imageUrl = maps[i]['imageUrl'] as String?;
      final String normalizedImageUrl = imageUrl != null 
          ? ImagePathUtils.normalizeImagePath(imageUrl)
          : '';
      
      // Normalize images list
      final String? imagesStr = maps[i]['images'] as String?;
      final List<String> normalizedImages = (imagesStr?.split(',') ?? [])
          .where((img) => img.isNotEmpty)
          .map((img) => ImagePathUtils.normalizeImagePath(img))
          .toList();

      final List<dynamic> uniqueFeatures =
          _decodeUniqueFeatures(maps[i]['uniqueFeatures'] as String?);
      
      return Pagoda.fromJson({
        ...maps[i],
        'imageUrl': normalizedImageUrl,
        'images': normalizedImages,
        'uniqueFeatures': uniqueFeatures,
        'isFavorite': maps[i]['isFavorite'] == 1,
      });
    });
  }
  
  Future<List<Pagoda>> getPagodasByCategory(String category) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tablePagodas,
      where: 'category = ?',
      whereArgs: [category],
    );
    
    return List.generate(maps.length, (i) {
      // Normalize image path
      final String? imageUrl = maps[i]['imageUrl'] as String?;
      final String normalizedImageUrl = imageUrl != null 
          ? ImagePathUtils.normalizeImagePath(imageUrl)
          : '';
      
      // Normalize images list
      final String? imagesStr = maps[i]['images'] as String?;
      final List<String> normalizedImages = (imagesStr?.split(',') ?? [])
          .where((img) => img.isNotEmpty)
          .map((img) => ImagePathUtils.normalizeImagePath(img))
          .toList();

      final List<dynamic> uniqueFeatures =
          _decodeUniqueFeatures(maps[i]['uniqueFeatures'] as String?);
      
      return Pagoda.fromJson({
        ...maps[i],
        'imageUrl': normalizedImageUrl,
        'images': normalizedImages,
        'uniqueFeatures': uniqueFeatures,
        'isFavorite': maps[i]['isFavorite'] == 1,
      });
    });
  }

  List<dynamic> _decodeUniqueFeatures(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded;
      }
    } catch (_) {
      return const [];
    }
    return const [];
  }
  
  // Favorites
  Future<void> toggleFavorite(String pagodaId) async {
    final db = await database;
    final isFav = await isFavorite(pagodaId);
    
    if (isFav) {
      await db.delete(
        AppConstants.tableFavorites,
        where: 'pagodaId = ?',
        whereArgs: [pagodaId],
      );
      await db.update(
        AppConstants.tablePagodas,
        {'isFavorite': 0},
        where: 'id = ?',
        whereArgs: [pagodaId],
      );
    } else {
      await db.insert(
        AppConstants.tableFavorites,
        {'pagodaId': pagodaId, 'addedAt': DateTime.now().toIso8601String()},
      );
      await db.update(
        AppConstants.tablePagodas,
        {'isFavorite': 1},
        where: 'id = ?',
        whereArgs: [pagodaId],
      );
    }
  }
  
  Future<bool> isFavorite(String pagodaId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tableFavorites,
      where: 'pagodaId = ?',
      whereArgs: [pagodaId],
    );
    return maps.isNotEmpty;
  }
  
  Future<List<Pagoda>> getFavorites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.* FROM ${AppConstants.tablePagodas} p
      INNER JOIN ${AppConstants.tableFavorites} f ON p.id = f.pagodaId
      ORDER BY f.addedAt DESC
    ''');
    
    return List.generate(maps.length, (i) {
      // Normalize image path
      final String? imageUrl = maps[i]['imageUrl'] as String?;
      final String normalizedImageUrl = imageUrl != null 
          ? ImagePathUtils.normalizeImagePath(imageUrl)
          : '';
      
      // Normalize images list
      final String? imagesStr = maps[i]['images'] as String?;
      final List<String> normalizedImages = (imagesStr?.split(',') ?? [])
          .where((img) => img.isNotEmpty)
          .map((img) => ImagePathUtils.normalizeImagePath(img))
          .toList();

      final List<dynamic> uniqueFeatures =
          _decodeUniqueFeatures(maps[i]['uniqueFeatures'] as String?);
      
      return Pagoda.fromJson({
        ...maps[i],
        'imageUrl': normalizedImageUrl,
        'images': normalizedImages,
        'uniqueFeatures': uniqueFeatures,
        'isFavorite': true,
      });
    });
  }
  
  // Trip CRUD operations
  Future<String> insertTrip(Trip trip) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.insert(
        AppConstants.tableTrips,
        {
          'id': trip.id,
          'name': trip.name,
          'description': trip.description,
          'date': trip.date.toIso8601String(),
          'createdAt': trip.createdAt.toIso8601String(),
          'updatedAt': trip.updatedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete(
        AppConstants.tableTripStops,
        where: 'tripId = ?',
        whereArgs: [trip.id],
      );

      // Insert stops
      for (var stop in trip.stops) {
        await txn.insert(
          AppConstants.tableTripStops,
          {
            'tripId': trip.id,
            'pagodaId': stop.pagodaId,
            'pagodaName': stop.pagodaName,
            'latitude': stop.latitude,
            'longitude': stop.longitude,
            'orderIndex': stop.order,
            'notes': stop.notes,
            'distanceToNext': stop.distanceToNext,
          },
        );
      }
    });

    return trip.id;
  }
  
  Future<List<Trip>> getAllTrips() async {
    final db = await database;
    final List<Map<String, dynamic>> tripMaps = await db.query(
      AppConstants.tableTrips,
      orderBy: 'date DESC',
    );
    
    if (tripMaps.isEmpty) return [];

    final tripIds = tripMaps.map((map) => map['id'] as String).toList();
    final placeholders = List.filled(tripIds.length, '?').join(',');
    final stopMaps = await db.query(
      AppConstants.tableTripStops,
      where: 'tripId IN ($placeholders)',
      whereArgs: tripIds,
      orderBy: 'tripId ASC, orderIndex ASC',
    );

    final stopsByTripId = <String, List<Map<String, dynamic>>>{};
    for (final stop in stopMaps) {
      final tripId = stop['tripId'] as String;
      stopsByTripId.putIfAbsent(tripId, () => []).add(stop);
    }

    return tripMaps.map((tripMap) {
      final stops = stopsByTripId[tripMap['id']] ?? const [];
      return Trip.fromJson({
        ...tripMap,
        'stops': stops.map((s) => {
          'pagodaId': s['pagodaId'],
          'pagodaName': s['pagodaName'],
          'latitude': s['latitude'],
          'longitude': s['longitude'],
          'order': s['orderIndex'],
          'notes': s['notes'],
          'distanceToNext': s['distanceToNext'],
        }).toList(),
      });
    }).toList();
  }
  
  Future<Trip?> getTripById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> tripMaps = await db.query(
      AppConstants.tableTrips,
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (tripMaps.isEmpty) return null;
    
    final List<Map<String, dynamic>> stopMaps = await db.query(
      AppConstants.tableTripStops,
      where: 'tripId = ?',
      whereArgs: [id],
      orderBy: 'orderIndex ASC',
    );
    
    return Trip.fromJson({
      ...tripMaps.first,
      'stops': stopMaps.map((s) => {
        'pagodaId': s['pagodaId'],
        'pagodaName': s['pagodaName'],
        'latitude': s['latitude'],
        'longitude': s['longitude'],
        'order': s['orderIndex'],
        'notes': s['notes'],
        'distanceToNext': s['distanceToNext'],
      }).toList(),
    });
  }
  
  Future<int> deleteTrip(String id) async {
    final db = await database;
    await db.delete(
      AppConstants.tableTripStops,
      where: 'tripId = ?',
      whereArgs: [id],
    );
    return await db.delete(
      AppConstants.tableTrips,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(AppConstants.tablePagodas);
    await db.delete(AppConstants.tableTrips);
    await db.delete(AppConstants.tableTripStops);
    await db.delete(AppConstants.tableFavorites);
  }
}
