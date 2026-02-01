import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import 'database_migration.dart';

class MigrationToV5 implements DatabaseMigration {
  @override
  int get targetVersion => 5;

  @override
  Future<void> migrate(Database db) async {
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
}
