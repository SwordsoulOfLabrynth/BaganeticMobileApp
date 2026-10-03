import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_constants.dart';
import 'logger.dart';

// Conditional import for InternetAddress - only import on non-web
import 'dart:io' if (dart.library.html) 'dart:html' show InternetAddress;

enum OfflineMapStatus { notDownloaded, downloading, ready, partial, failed }

class OfflineMapService {
  OfflineMapService._();

  static final OfflineMapService instance = OfflineMapService._();

  static const String _statusKey = 'offline_map_status_v1';
  static const String _updatedKey = 'offline_map_updated_v1';

  static const String _statusComplete = 'complete';
  static const String _statusPartial = 'partial';
  static const String _statusFailed = 'failed';
  static const String _statusInProgress = 'in_progress';
  static const String _statusNotDownloaded = 'not_downloaded';

  static const int _minZoom = 12;
  static const int _maxZoom = 16;
  static const Duration _staleInProgressThreshold = Duration(hours: 6);

  final ValueNotifier<OfflineMapStatus> statusNotifier =
      ValueNotifier<OfflineMapStatus>(OfflineMapStatus.notDownloaded);

  bool _isDownloading = false;

  bool get isDownloading => _isDownloading;

  Future<OfflineMapStatus> getStatus() async {
    final store = const FMTCStore(AppConstants.mapTileStore);
    final status = statusFromMetadata(await store.metadata.read);
    statusNotifier.value = status;
    return status;
  }

  Future<({double sizeMb, int tileCount})> getCacheStats() async {
    try {
      final store = const FMTCStore(AppConstants.mapTileStore);
      if (!await store.manage.ready) {
        return (sizeMb: 0.0, tileCount: 0);
      }
      final stats = await store.stats.all;
      return (sizeMb: stats.size / 1024, tileCount: stats.length);
    } catch (_) {
      return (sizeMb: 0.0, tileCount: 0);
    }
  }

  Future<void> clearCache() async {
    final store = const FMTCStore(AppConstants.mapTileStore);
    try {
      if (await store.manage.ready) {
        await store.manage.reset();
      }
      await _updateStatus(store, _statusNotDownloaded);
    } catch (e) {
      Logger.error('Failed to clear map tile cache', e);
    }
  }

  @visibleForTesting
  static OfflineMapStatus statusFromMetadata(Map<String, String> metadata) {
    return switch (metadata[_statusKey]) {
      _statusComplete => OfflineMapStatus.ready,
      _statusInProgress => OfflineMapStatus.downloading,
      _statusPartial => OfflineMapStatus.partial,
      _statusFailed => OfflineMapStatus.failed,
      _ => OfflineMapStatus.notDownloaded,
    };
  }

  Future<void> startBackgroundPrefetch({bool force = false}) async {
    if (_isDownloading) return;

    final store = const FMTCStore(AppConstants.mapTileStore);
    final metadata = await store.metadata.read;
    final status = metadata[_statusKey];
    final lastUpdated = DateTime.tryParse(metadata[_updatedKey] ?? '');

    if (!force && status == _statusComplete) {
      return;
    }

    if (!force && status == _statusInProgress) {
      final isStale =
          lastUpdated == null ||
          DateTime.now().difference(lastUpdated) > _staleInProgressThreshold;
      if (!isStale) {
        return;
      }
    }

    if (!await _hasNetwork()) {
      return;
    }

    _isDownloading = true;
    statusNotifier.value = OfflineMapStatus.downloading;

    try {
      await store.metadata.setBulk(
        kvs: {
          _statusKey: _statusInProgress,
          _updatedKey: DateTime.now().toIso8601String(),
        },
      );

      final region = RectangleRegion(_baganBounds()).toDownloadable(
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        options: TileLayer(
          urlTemplate: AppConstants.mapTileUrlTemplate,
          subdomains: AppConstants.mapTileSubdomains,
          userAgentPackageName: AppConstants.mapTileUserAgent,
        ),
      );

      final streams = store.download.startForeground(
        region: region,
        parallelThreads: 3,
        maxBufferLength: 120,
        skipExistingTiles: true,
        skipSeaTiles: true,
        rateLimit: 2,
      );

      DownloadProgress? lastProgress;
      streams.downloadProgress.listen(
        (evt) => lastProgress = evt,
        onError: (error, _) {
          unawaited(_updateStatus(store, _statusFailed));
          _isDownloading = false;
        },
        onDone: () {
          final failedTiles = lastProgress?.failedTilesCount ?? 0;
          final status = failedTiles == 0 ? _statusComplete : _statusPartial;
          unawaited(_updateStatus(store, status));
          _isDownloading = false;
        },
      );
    } catch (e) {
      await _updateStatus(store, _statusFailed);
      _isDownloading = false;
      Logger.error('Offline map prefetch failed', e);
    }
  }

  LatLngBounds _baganBounds() {
    return LatLngBounds(
      LatLng(
        AppConstants.baganLatitude - AppConstants.mapCoverageLatitudePadding,
        AppConstants.baganLongitude - AppConstants.mapCoverageLongitudePadding,
      ),
      LatLng(
        AppConstants.baganLatitude + AppConstants.mapCoverageLatitudePadding,
        AppConstants.baganLongitude + AppConstants.mapCoverageLongitudePadding,
      ),
    );
  }

  Future<void> _updateStatus(FMTCStore store, String status) async {
    await store.metadata.setBulk(
      kvs: {_statusKey: status, _updatedKey: DateTime.now().toIso8601String()},
    );
    statusNotifier.value = statusFromMetadata({_statusKey: status});
  }

  Future<bool> _hasNetwork() async {
    if (kIsWeb) {
      // On web, assume network is available if we can reach here
      // You could use a more sophisticated check if needed
      return true;
    }
    // Use InternetAddress only on non-web platforms
    try {
      final result = await InternetAddress.lookup(
        'tile.openstreetmap.org',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
