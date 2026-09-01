import 'dart:io';

import 'package:baganetic_mobile/data/datasources/migrations/migration_v13.dart';
import 'package:baganetic_mobile/data/datasources/migrations/migration_v14.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('v13 and v14 upgrades preserve legacy records and add safe defaults',
      () async {
    final directory = await Directory.systemTemp.createTemp('baganetic-db-');
    final databasePath = '${directory.path}${Platform.pathSeparator}legacy.db';
    final database = await databaseFactoryFfi.openDatabase(databasePath);

    try {
      await database.execute('''
        CREATE TABLE pagodas (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL
        )
      ''');
      await database.execute('''
        CREATE TABLE trips (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL
        )
      ''');
      await database.insert('pagodas', {'id': 'ananda', 'name': 'Ananda'});
      await database.insert('trips', {'id': 'day-one', 'name': 'Day one'});

      await MigrationToV13().migrate(database);
      await MigrationToV14().migrate(database);

      final pagoda = (await database.query('pagodas')).single;
      final trip = (await database.query('trips')).single;
      expect(pagoda['id'], 'ananda');
      expect(pagoda['isHomeFeatured'], 0);
      expect(pagoda['homeFeaturedOrder'], 0);
      expect(trip['id'], 'day-one');
      expect(trip['transportMode'], 'walk');
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}
