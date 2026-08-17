import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import 'database_migration.dart';

class MigrationToV14 implements DatabaseMigration {
  @override
  int get targetVersion => 14;

  @override
  Future<void> migrate(Database db) async {
    for (final statement in [
      'ALTER TABLE ${AppConstants.tablePagodas} '
          'ADD COLUMN isHomeFeatured INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE ${AppConstants.tablePagodas} '
          'ADD COLUMN homeFeaturedOrder INTEGER NOT NULL DEFAULT 0',
    ]) {
      try {
        await db.execute(statement);
      } on DatabaseException {
        // The self-heal path can run after an interrupted migration.
      }
    }
  }
}
