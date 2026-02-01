import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import 'database_migration.dart';

class MigrationToV7 implements DatabaseMigration {
  @override
  int get targetVersion => 7;

  @override
  Future<void> migrate(Database db) async {
    final columns = <String, String>{
      'legends': 'TEXT',
      'religiousImportance': 'TEXT',
      'preservationInfo': 'TEXT',
      'bestTimeToVisit': 'TEXT',
      'visitorLocation': 'TEXT',
      'openingHours': 'TEXT',
      'dressCode': 'TEXT',
      'entranceFee': 'TEXT',
      'photographyRules': 'TEXT',
      'height': 'TEXT',
      'finalWords': 'TEXT',
      'uniqueFeatures': 'TEXT',
    };

    for (final entry in columns.entries) {
      await _addColumn(db, entry.key, entry.value);
    }
  }

  Future<void> _addColumn(Database db, String name, String type) async {
    try {
      await db.execute(
        'ALTER TABLE ${AppConstants.tablePagodas} ADD COLUMN $name $type',
      );
    } on DatabaseException {
      // Ignore if the column already exists.
    }
  }
}
