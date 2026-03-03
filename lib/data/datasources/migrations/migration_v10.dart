import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import 'database_migration.dart';

class MigrationToV10 implements DatabaseMigration {
  @override
  int get targetVersion => 10;

  @override
  Future<void> migrate(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableFeedbacks} (
        id TEXT PRIMARY KEY,
        pagodaId TEXT NOT NULL,
        userId TEXT NOT NULL,
        userName TEXT NOT NULL,
        rating INTEGER NOT NULL,
        comment TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_feedbacks_pagoda_created_at
      ON ${AppConstants.tableFeedbacks} (pagodaId, createdAt DESC)
    ''');
  }
}
