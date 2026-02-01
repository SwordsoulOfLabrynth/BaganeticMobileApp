import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/logger.dart';
import '../../../core/utils/image_path_utils.dart';
import 'database_migration.dart';

class MigrationToV4 implements DatabaseMigration {
  @override
  int get targetVersion => 4;

  @override
  Future<void> migrate(Database db) async {
    Logger.info('Database upgrade: Fixing image paths...');

    final List<Map<String, dynamic>> pagodas =
        await db.query(AppConstants.tablePagodas);

    var fixedCount = 0;
    for (final pagoda in pagodas) {
      final String? oldPath = pagoda['imageUrl'] as String?;
      if (oldPath != null && oldPath.isNotEmpty) {
        final String normalizedPath = ImagePathUtils.normalizeImagePath(oldPath);
        if (normalizedPath != oldPath) {
          await db.update(
            AppConstants.tablePagodas,
            {'imageUrl': normalizedPath},
            where: 'id = ?',
            whereArgs: [pagoda['id']],
          );
          Logger.info(
              'Fixed image path for ${pagoda['name']}: $oldPath -> $normalizedPath');
          fixedCount++;
        }
      }

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

    Logger.info('Database upgrade: Normalized $fixedCount image paths.');
  }
}
