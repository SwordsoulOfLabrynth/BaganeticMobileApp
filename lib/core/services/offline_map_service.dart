import 'dart:async';
import 'dart:io';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_constants.dart';
import 'logger.dart';

class OfflineMapService {
  OfflineMapService._();

  static final OfflineMapService instance = OfflineMapService._();

  static const String _statusKey = 'offline_map_status_v1';
  static const String _updatedKey = 'offline_map_updated_v1';

  static const String _statusComplete = 'complete';
  static const String _statusPartial = 'partial';
  static const String _statusFailed = 'failed';
  static const String _statusInProgress = 'in_progress';

  static const int _minZoom = 12;
  static const int _maxZoom = 16;
  static const double _latPadding = 0.20;
  static const double _lngPadding = 0.20;
  static const Duration _staleInProgressThreshold = Duration(hours: 6);

  bool _isDownloading = false;

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
      final isStale = lastUpdated == null ||
          DateTime.now().difference(lastUpdated) > _staleInProgressThreshold;
      if (!isStale) {
        return;
      }
    }

    if (!await _hasNetwork()) {
      return;
    }

    _isDownloading = true;

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
          userAgentPackageName: 'com.baganetic.app',
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
        AppConstants.baganLatitude - _latPadding,
        AppConstants.baganLongitude - _lngPadding,
      ),
      LatLng(
        AppConstants.baganLatitude + _latPadding,
        AppConstants.baganLongitude + _lngPadding,
      ),
    );
  }

  Future<void> _updateStatus(FMTCStore store, String status) {
    return store.metadata.setBulk(
      kvs: {
        _statusKey: status,
        _updatedKey: DateTime.now().toIso8601String(),
      },
    );
  }

  Future<bool> _hasNetwork() async {
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
