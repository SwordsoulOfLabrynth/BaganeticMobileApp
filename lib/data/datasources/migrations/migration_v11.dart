import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import 'database_migration.dart';

class MigrationToV11 implements DatabaseMigration {
  @override
  int get targetVersion => 11;

  @override
  Future<void> migrate(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableCommunityPosts} (
        id TEXT PRIMARY KEY,
        authorUserId TEXT NOT NULL,
        authorName TEXT NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        tags TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL DEFAULT 'active',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableCommunityComments} (
        id TEXT PRIMARY KEY,
        postId TEXT NOT NULL,
        authorUserId TEXT NOT NULL,
        authorName TEXT NOT NULL,
        body TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableCommunityPostVotes} (
        postId TEXT NOT NULL,
        userId TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        PRIMARY KEY (postId, userId)
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_community_posts_updated_at
      ON ${AppConstants.tableCommunityPosts} (updatedAt DESC)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_community_comments_post_created_at
      ON ${AppConstants.tableCommunityComments} (postId, createdAt ASC)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_community_votes_post_id
      ON ${AppConstants.tableCommunityPostVotes} (postId)
    ''');
  }
}
