import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import 'database_migration.dart';

class MigrationToV9 implements DatabaseMigration {
  @override
  int get targetVersion => 9;

  @override
  Future<void> migrate(Database db) async {
    final favoritesTable = AppConstants.tableFavorites;
    final legacyTable = '${AppConstants.tableFavorites}_legacy';

    final favoritesExists = await _tableExists(db, favoritesTable);
    final legacyExists = await _tableExists(db, legacyTable);

    if (legacyExists && !favoritesExists) {
      await _rebuildFromLegacy(db, legacyTable: legacyTable);
      return;
    }

    if (!favoritesExists) {
      await _createFavoritesTable(db);
      return;
    }

    final hasOwnerUserId = await _columnExists(
      db,
      table: favoritesTable,
      column: 'ownerUserId',
    );
    final hasPagodaId = await _columnExists(
      db,
      table: favoritesTable,
      column: 'pagodaId',
    );
    final hasAddedAt = await _columnExists(
      db,
      table: favoritesTable,
      column: 'addedAt',
    );

    if (hasOwnerUserId && hasPagodaId && hasAddedAt) {
      if (legacyExists) {
        await db.execute('DROP TABLE $legacyTable');
      }
      return;
    }

    await db.transaction((txn) async {
      if (await _tableExists(txn, legacyTable)) {
        await txn.execute('DROP TABLE $legacyTable');
      }
      await txn.execute('ALTER TABLE $favoritesTable RENAME TO $legacyTable');
      await _createFavoritesTable(txn);

      final legacyHasPagodaId = await _columnExists(
        txn,
        table: legacyTable,
        column: 'pagodaId',
      );
      final legacyHasAddedAt = await _columnExists(
        txn,
        table: legacyTable,
        column: 'addedAt',
      );

      if (legacyHasPagodaId) {
        if (legacyHasAddedAt) {
          await txn.execute('''
            INSERT OR IGNORE INTO $favoritesTable(ownerUserId, pagodaId, addedAt)
            SELECT '${AppConstants.guestOwnerId}', pagodaId, addedAt
            FROM $legacyTable
          ''');
        } else {
          await txn.execute('''
            INSERT OR IGNORE INTO $favoritesTable(ownerUserId, pagodaId, addedAt)
            SELECT '${AppConstants.guestOwnerId}', pagodaId, datetime('now')
            FROM $legacyTable
          ''');
        }
      }

      await txn.execute('DROP TABLE $legacyTable');
    });
  }

  Future<void> _rebuildFromLegacy(Database db, {
    required String legacyTable,
  }) async {
    await db.transaction((txn) async {
      await _createFavoritesTable(txn);
      final legacyHasPagodaId = await _columnExists(
        txn,
        table: legacyTable,
        column: 'pagodaId',
      );
      final legacyHasAddedAt = await _columnExists(
        txn,
        table: legacyTable,
        column: 'addedAt',
      );

      if (legacyHasPagodaId) {
        if (legacyHasAddedAt) {
          await txn.execute('''
            INSERT OR IGNORE INTO ${AppConstants.tableFavorites}(ownerUserId, pagodaId, addedAt)
            SELECT '${AppConstants.guestOwnerId}', pagodaId, addedAt
            FROM $legacyTable
          ''');
        } else {
          await txn.execute('''
            INSERT OR IGNORE INTO ${AppConstants.tableFavorites}(ownerUserId, pagodaId, addedAt)
            SELECT '${AppConstants.guestOwnerId}', pagodaId, datetime('now')
            FROM $legacyTable
          ''');
        }
      }

      await txn.execute('DROP TABLE $legacyTable');
    });
  }

  Future<void> _createFavoritesTable(DatabaseExecutor db) {
    return db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableFavorites} (
        ownerUserId TEXT NOT NULL,
        pagodaId TEXT NOT NULL,
        addedAt TEXT NOT NULL,
        PRIMARY KEY (ownerUserId, pagodaId)
      )
    ''');
  }

  Future<bool> _tableExists(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<bool> _columnExists(
    DatabaseExecutor db, {
    required String table,
    required String column,
  }) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.any((row) => row['name'] == column);
  }
}
