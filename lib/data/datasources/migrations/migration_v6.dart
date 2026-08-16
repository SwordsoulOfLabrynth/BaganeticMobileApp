import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import 'database_migration.dart';

class MigrationToV6 implements DatabaseMigration {
  @override
  int get targetVersion => 6;

  @override
  Future<void> migrate(Database db) async {
    final idRenames = <String, String>{
      'thatbyinnyu': 'thatbinnyu',
      'mahezedi': 'mahazedi',
    };

    for (final entry in idRenames.entries) {
      await db.update(
        AppConstants.tablePagodas,
        {'id': entry.value},
        where: 'id = ?',
        whereArgs: [entry.key],
      );
      await db.update(
        AppConstants.tableTripStops,
        {'pagodaId': entry.value},
        where: 'pagodaId = ?',
        whereArgs: [entry.key],
      );
      await db.update(
        AppConstants.tableFavorites,
        {'pagodaId': entry.value},
        where: 'pagodaId = ?',
        whereArgs: [entry.key],
      );
    }

    final coordMap = <String, List<double>>{
      'alodawpyae': [21.176739, 94.882814],
      'ananda': [21.170806, 94.867856],
      'bupaya': [21.1763128, 94.857903],
      'dhammayangyi': [21.161975, 94.872919],
      'dhammayazaka': [21.145071, 94.883451],
      'gawdawpalin': [21.17, 94.856667],
      'gubyaukgyi': [21.157222, 94.860833],
      'htilominlo': [21.178531, 94.879398],
      'izagawna': [21.17025, 94.90586],
      'lawkananda': [21.127222, 94.850556],
      'mahazedi': [21.1645, 94.86229],
      'manuha': [21.153408, 94.859152],
      'pyathetgyi': [21.15829, 94.88957],
      'seinnyetnyiama': [21.14151, 94.85896],
      'shwegugyi': [21.170744, 94.862406],
      'shwezigon': [21.195278, 94.893889],
      'sulamani': [21.1649, 94.8814],
      'thambula': [21.162594, 94.903672],
      'thatbinnyu': [21.16875, 94.86295],
    };

    for (final entry in coordMap.entries) {
      await db.update(
        AppConstants.tablePagodas,
        {'latitude': entry.value[0], 'longitude': entry.value[1]},
        where: 'id = ?',
        whereArgs: [entry.key],
      );
      await db.update(
        AppConstants.tableTripStops,
        {'latitude': entry.value[0], 'longitude': entry.value[1]},
        where: 'pagodaId = ?',
        whereArgs: [entry.key],
      );
    }
  }
}
