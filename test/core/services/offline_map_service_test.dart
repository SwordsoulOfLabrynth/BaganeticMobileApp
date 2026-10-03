import 'package:baganetic_mobile/core/services/offline_map_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports each persisted offline map download state', () {
    expect(
      OfflineMapService.statusFromMetadata(
        const {'offline_map_status_v1': 'complete'},
      ),
      OfflineMapStatus.ready,
    );
    expect(
      OfflineMapService.statusFromMetadata(
        const {'offline_map_status_v1': 'in_progress'},
      ),
      OfflineMapStatus.downloading,
    );
    expect(
      OfflineMapService.statusFromMetadata(
        const {'offline_map_status_v1': 'partial'},
      ),
      OfflineMapStatus.partial,
    );
    expect(
      OfflineMapService.statusFromMetadata(
        const {'offline_map_status_v1': 'failed'},
      ),
      OfflineMapStatus.failed,
    );
    expect(
      OfflineMapService.statusFromMetadata(
        const {'offline_map_status_v1': 'not_downloaded'},
      ),
      OfflineMapStatus.notDownloaded,
    );
  });

  test('treats missing offline map metadata as not downloaded', () {
    expect(
      OfflineMapService.statusFromMetadata(const {}),
      OfflineMapStatus.notDownloaded,
    );
  });

  test('provides reactive statusNotifier with initial status', () {
    final service = OfflineMapService.instance;
    expect(service.statusNotifier.value, isNotNull);
    expect(service.isDownloading, isFalse);
  });
}
