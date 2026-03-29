import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import 'database_migration.dart';

class MigrationToV12 implements DatabaseMigration {
  @override
  int get targetVersion => 12;

  @override
  Future<void> migrate(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableAiChatMessagesLocal} (
        id TEXT PRIMARY KEY,
        ownerUserId TEXT NOT NULL,
        role TEXT NOT NULL,
        text TEXT NOT NULL,
        requestId TEXT,
        contextType TEXT,
        pagodaId TEXT,
        tripId TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_ai_chat_local_owner_created_at
      ON ${AppConstants.tableAiChatMessagesLocal} (ownerUserId, createdAt ASC)
    ''');
  }
}
