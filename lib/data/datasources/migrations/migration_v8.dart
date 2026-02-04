import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import 'database_migration.dart';

class MigrationToV8 implements DatabaseMigration {
  @override
  int get targetVersion => 8;

  @override
  Future<void> migrate(Database db) async {
    try {
      await db.execute(
        'ALTER TABLE ${AppConstants.tableTrips} ADD COLUMN ownerUserId TEXT',
      );
    } on DatabaseException {
      // Ignore if the column already exists.
    }
  }
}
