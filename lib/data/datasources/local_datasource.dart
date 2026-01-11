import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/pagoda_model.dart';
import '../models/trip_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/image_path_utils.dart';

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
    // For versions < 4, fix image paths in existing data
    if (oldVersion < 4) {
      print('Database upgrade: Fixing image paths...');
      
      // Get all pagodas with incorrect paths
      final List<Map<String, dynamic>> pagodas = await db.query(AppConstants.tablePagodas);
      
      int fixedCount = 0;
      for (var pagoda in pagodas) {
        final String? oldPath = pagoda['imageUrl'] as String?;
        if (oldPath != null && oldPath.isNotEmpty) {
          // Normalize all paths, not just those with duplicates
          final String normalizedPath = ImagePathUtils.normalizeImagePath(oldPath);
          
          // Only update if path changed
          if (normalizedPath != oldPath) {
            await db.update(
              AppConstants.tablePagodas,
              {'imageUrl': normalizedPath},
              where: 'id = ?',
              whereArgs: [pagoda['id']],
            );
            
            print('Fixed image path for ${pagoda['name']}: $oldPath -> $normalizedPath');
            fixedCount++;
          }
        }
        
        // Also normalize images list if it exists
        final String? imagesStr = pagoda['images'] as String?;
        if (imagesStr != null && imagesStr.isNotEmpty) {
          final List<String> imageList = imagesStr.split(',');
          final List<String> normalizedImages = imageList
              .where((img) => img.isNotEmpty)
              .map((img) => ImagePathUtils.normalizeImagePath(img))
              .toList();
          
          final String normalizedImagesStr = normalizedImages.join(',');
          if (normalizedImagesStr != imagesStr) {
            await db.update(
              AppConstants.tablePagodas,
              {'images': normalizedImagesStr},
              where: 'id = ?',
              whereArgs: [pagoda['id']],
            );
            fixedCount++;
          }
        }
      }
      
      print('Database upgrade: Normalized $fixedCount image paths.');
    }

    if (oldVersion < 5) {
      final pagodas = await db.query(
        AppConstants.tablePagodas,
        columns: ['id', 'latitude', 'longitude'],
      );
      for (final pagoda in pagodas) {
        final lat = (pagoda['latitude'] as num).toDouble();
        final lon = (pagoda['longitude'] as num).toDouble();
        if (lat.abs() > 90 && lon.abs() <= 90) {
          await db.update(
            AppConstants.tablePagodas,
            {'latitude': lon, 'longitude': lat},
            where: 'id = ?',
            whereArgs: [pagoda['id']],
          );
        }
      }

      final tripStops = await db.query(
        AppConstants.tableTripStops,
        columns: ['id', 'latitude', 'longitude'],
      );
      for (final stop in tripStops) {
        final lat = (stop['latitude'] as num).toDouble();
        final lon = (stop['longitude'] as num).toDouble();
        if (lat.abs() > 90 && lon.abs() <= 90) {
          await db.update(
            AppConstants.tableTripStops,
            {'latitude': lon, 'longitude': lat},
            where: 'id = ?',
            whereArgs: [stop['id']],
          );
        }
      }
    }

    if (oldVersion < 6) {
      final idRenames = <String, String>{
        'thatbyinnyu': 'thatbinnyu',
        'mahezedi': 'mahazedi',
      };

      for (final entry in idRenames.entries) {
        await db.update(
          AppConstants.tablePagodas,
          {'id': entry.value},
          where: 'id = ?',
          whereArgs: [entry.key],
        );
        await db.update(
          AppConstants.tableTripStops,
          {'pagodaId': entry.value},
          where: 'pagodaId = ?',
          whereArgs: [entry.key],
        );
        await db.update(
          AppConstants.tableFavorites,
          {'pagodaId': entry.value},
          where: 'pagodaId = ?',
          whereArgs: [entry.key],
        );
      }

      final coordMap = <String, List<double>>{
        'alodawpyae': [21.176739, 94.882814],
        'ananda': [21.170806, 94.867856],
        'bupaya': [21.1763128, 94.857903],
        'dhammayangyi': [21.161975, 94.872919],
        'dhammayazaka': [21.145071, 94.883451],
        'gawdawpalin': [21.17, 94.856667],
        'gubyaukgyi': [21.157222, 94.860833],
        'htilominlo': [21.178531, 94.879398],
        'izagawna': [21.17025, 94.90586],
        'lawkananda': [21.127222, 94.850556],
        'mahazedi': [21.1645, 94.86229],
        'manuha': [21.153408, 94.859152],
        'pyathetgyi': [21.15829, 94.88957],
        'seinnyetnyiama': [21.14151, 94.85896],
        'shwegugyi': [21.170744, 94.862406],
        'shwezigon': [21.195278, 94.893889],
        'sulamani': [21.1649, 94.8814],
        'thambula': [21.162594, 94.903672],
        'thatbinnyu': [21.16875, 94.86295],
      };

      for (final entry in coordMap.entries) {
        await db.update(
          AppConstants.tablePagodas,
          {
            'latitude': entry.value[0],
            'longitude': entry.value[1],
          },
          where: 'id = ?',
          whereArgs: [entry.key],
        );
        await db.update(
          AppConstants.tableTripStops,
          {
            'latitude': entry.value[0],
            'longitude': entry.value[1],
          },
          where: 'pagodaId = ?',
          whereArgs: [entry.key],
        );
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
    
    return await db.insert(
      AppConstants.tablePagodas,
      {
        ...pagoda.toJson(),
        'imageUrl': normalizedImageUrl,
        'images': normalizedImages.join(','),
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
      
      return Pagoda.fromJson({
        ...maps[i],
        'imageUrl': normalizedImageUrl,
        'images': normalizedImages,
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
    
    return Pagoda.fromJson({
      ...maps.first,
      'imageUrl': normalizedImageUrl,
      'images': normalizedImages,
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
      
      return Pagoda.fromJson({
        ...maps[i],
        'imageUrl': normalizedImageUrl,
        'images': normalizedImages,
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
      
      return Pagoda.fromJson({
        ...maps[i],
        'imageUrl': normalizedImageUrl,
        'images': normalizedImages,
        'isFavorite': maps[i]['isFavorite'] == 1,
      });
    });
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
      
      return Pagoda.fromJson({
        ...maps[i],
        'imageUrl': normalizedImageUrl,
        'images': normalizedImages,
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
