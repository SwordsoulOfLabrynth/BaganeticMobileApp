import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/firestore_instance.dart';
import '../../core/services/logger.dart';
import '../datasources/local_datasource.dart';
import '../models/pagoda_model.dart';

class PagodaDataService {
  PagodaDataService({DatabaseService? databaseService})
    : _db = databaseService ?? DatabaseService();

  final DatabaseService _db;

  Future<List<Pagoda>> loadPagodas({String? ownerUserId}) async {
    final bundledPagodas = await _loadSamplePagodas();
    final remotePagodas = await _loadRemotePagodas();
    if (remotePagodas.isNotEmpty) {
      final preferredCatalog = _mergeCatalogs(
        remotePagodas: remotePagodas,
        bundledPagodas: bundledPagodas,
      );
      try {
        await _db.syncPagodaCatalog(preferredCatalog);
        final syncedPagodas = await _db.getAllPagodas(ownerUserId: ownerUserId);
        Logger.info(
          'Loaded ${syncedPagodas.length} pagodas from Firestore-backed catalog',
        );
        if (syncedPagodas.isNotEmpty) {
          return syncedPagodas;
        }
      } catch (e, stackTrace) {
        Logger.error(
          'Failed to sync Firestore pagoda catalog locally',
          e,
          stackTrace,
        );
        return preferredCatalog;
      }
    }

    try {
      var pagodas = await _db.getAllPagodas(ownerUserId: ownerUserId);

      if (pagodas.isEmpty) {
        Logger.info(
          'Database is empty, initializing with bundled pagoda data...',
        );
        await initializeSampleData(samplePagodas: bundledPagodas);
        pagodas = await _db.getAllPagodas(ownerUserId: ownerUserId);
        Logger.info('Initialized ${pagodas.length} pagodas with sample data');
      } else if (pagodas.isNotEmpty) {
        final didRefresh = await _refreshFromSampleIfNeeded(
          pagodas,
          bundledPagodas: bundledPagodas,
        );
        if (didRefresh) {
          pagodas = await _db.getAllPagodas(ownerUserId: ownerUserId);
          Logger.info('Refreshed pagoda data from sample JSON');
        }
        Logger.info('Loaded ${pagodas.length} pagodas from database');
      }

      if (pagodas.isNotEmpty) {
        return pagodas;
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to load pagodas from local database', e, stackTrace);
    }

    // Keep the app usable even when local DB init/query fails.
    final fallback = bundledPagodas;
    Logger.info(
      'Using bundled sample pagodas fallback (${fallback.length} items)',
    );
    return fallback;
  }

  Future<List<Pagoda>> _loadRemotePagodas() async {
    try {
      final snapshot = await FirestoreInstance.instance
          .collection(AppConstants.pagodas)
          .where('status', isEqualTo: AppConstants.pagodaStatusActive)
          .get();

      final remotePagodas =
          snapshot.docs
              .map((doc) => Pagoda.fromJson({'id': doc.id, ...doc.data()}))
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      if (remotePagodas.isNotEmpty) {
        Logger.info(
          'Fetched ${remotePagodas.length} active pagodas from Firestore',
        );
      }

      return remotePagodas;
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to load pagoda catalog from Firestore',
        e,
        stackTrace,
      );
      return const [];
    }
  }

  Future<void> initializeSampleData({List<Pagoda>? samplePagodas}) async {
    final pagodasToSync = samplePagodas ?? await _loadSamplePagodas();
    await _db.syncPagodaCatalog(pagodasToSync);
  }

  Future<List<Pagoda>> _loadSamplePagodas() async {
    final jsonString = await rootBundle.loadString(
      'assets/data/sample_pagodas.json',
    );
    final List<dynamic> jsonData = jsonDecode(jsonString) as List<dynamic>;
    return jsonData
        .map((item) => Pagoda.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<bool> _refreshFromSampleIfNeeded(
    List<Pagoda> existing, {
    List<Pagoda>? bundledPagodas,
  }) async {
    final samplePagodas = bundledPagodas ?? await _loadSamplePagodas();
    final Map<String, Pagoda> existingById = {
      for (final pagoda in existing) pagoda.id: pagoda,
    };
    final sampleIds = samplePagodas.map((pagoda) => pagoda.id).toSet();

    var updated = false;
    final deletedCount = await _db.deletePagodasNotIn(sampleIds);
    if (deletedCount > 0) {
      updated = true;
    }

    for (final sample in samplePagodas) {
      final current = existingById[sample.id];

      if (current == null) {
        await _db.insertPagoda(sample);
        updated = true;
        continue;
      }

      if (_needsRefresh(current, sample)) {
        final merged = sample.copyWith(isFavorite: current.isFavorite);
        await _db.insertPagoda(merged);
        updated = true;
      }
    }

    return updated;
  }

  List<Pagoda> _mergeCatalogs({
    required List<Pagoda> remotePagodas,
    required List<Pagoda> bundledPagodas,
  }) {
    if (bundledPagodas.isEmpty) {
      return remotePagodas;
    }

    final mergedById = <String, Pagoda>{
      for (final pagoda in bundledPagodas) pagoda.id: pagoda,
    };

    for (final remotePagoda in remotePagodas) {
      final bundledPagoda = mergedById[remotePagoda.id];
      mergedById[remotePagoda.id] = bundledPagoda == null
          ? remotePagoda
          : _mergePagoda(remotePagoda, bundledPagoda);
    }

    if (remotePagodas.length < bundledPagodas.length) {
      Logger.info(
        'Firestore pagoda catalog is incomplete '
        '(${remotePagodas.length}/${bundledPagodas.length}); '
        'filling missing entries from bundled data',
      );
    }

    return mergedById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Pagoda _mergePagoda(Pagoda remote, Pagoda bundled) {
    String pickRequired(String primary, String fallback) {
      return primary.trim().isNotEmpty ? primary : fallback;
    }

    String? pickOptional(String? primary, String? fallback) {
      if (primary != null && primary.trim().isNotEmpty) {
        return primary;
      }
      return fallback;
    }

    return bundled.copyWith(
      name: pickRequired(remote.name, bundled.name),
      description: pickRequired(remote.description, bundled.description),
      category: pickRequired(remote.category, bundled.category),
      latitude: remote.latitude,
      longitude: remote.longitude,
      imageUrl: pickRequired(remote.imageUrl, bundled.imageUrl),
      images: remote.images.isNotEmpty ? remote.images : bundled.images,
      historicalInfo: pickOptional(
        remote.historicalInfo,
        bundled.historicalInfo,
      ),
      architecturalStyle: pickOptional(
        remote.architecturalStyle,
        bundled.architecturalStyle,
      ),
      yearBuilt: remote.yearBuilt ?? bundled.yearBuilt,
      isHomeFeatured: remote.isHomeFeatured,
      homeFeaturedOrder: remote.homeFeaturedOrder,
      legends: pickOptional(remote.legends, bundled.legends),
      religiousImportance: pickOptional(
        remote.religiousImportance,
        bundled.religiousImportance,
      ),
      preservationInfo: pickOptional(
        remote.preservationInfo,
        bundled.preservationInfo,
      ),
      bestTimeToVisit: pickOptional(
        remote.bestTimeToVisit,
        bundled.bestTimeToVisit,
      ),
      visitorLocation: pickOptional(
        remote.visitorLocation,
        bundled.visitorLocation,
      ),
      openingHours: pickOptional(remote.openingHours, bundled.openingHours),
      dressCode: pickOptional(remote.dressCode, bundled.dressCode),
      entranceFee: pickOptional(remote.entranceFee, bundled.entranceFee),
      photographyRules: pickOptional(
        remote.photographyRules,
        bundled.photographyRules,
      ),
      height: pickOptional(remote.height, bundled.height),
      finalWords: pickOptional(remote.finalWords, bundled.finalWords),
      uniqueFeatures: remote.uniqueFeatures.isNotEmpty
          ? remote.uniqueFeatures
          : bundled.uniqueFeatures,
    );
  }

  bool _needsRefresh(Pagoda current, Pagoda sample) {
    bool missingOrEmpty(String? value, String? sampleValue) {
      if (sampleValue == null || sampleValue.trim().isEmpty) return false;
      return value == null || value.trim().isEmpty;
    }

    if (current.category != sample.category) {
      return true;
    }

    if (missingOrEmpty(current.historicalInfo, sample.historicalInfo) ||
        missingOrEmpty(current.architecturalStyle, sample.architecturalStyle) ||
        missingOrEmpty(current.legends, sample.legends) ||
        missingOrEmpty(
          current.religiousImportance,
          sample.religiousImportance,
        ) ||
        missingOrEmpty(current.preservationInfo, sample.preservationInfo) ||
        missingOrEmpty(current.bestTimeToVisit, sample.bestTimeToVisit) ||
        missingOrEmpty(current.finalWords, sample.finalWords) ||
        missingOrEmpty(current.visitorLocation, sample.visitorLocation) ||
        missingOrEmpty(current.openingHours, sample.openingHours) ||
        missingOrEmpty(current.dressCode, sample.dressCode) ||
        missingOrEmpty(current.entranceFee, sample.entranceFee) ||
        missingOrEmpty(current.photographyRules, sample.photographyRules) ||
        missingOrEmpty(current.height, sample.height)) {
      return true;
    }

    if (current.uniqueFeatures.isEmpty && sample.uniqueFeatures.isNotEmpty) {
      return true;
    }

    if (current.imageUrl != sample.imageUrl) {
      return true;
    }

    if (current.images.length < sample.images.length) {
      return true;
    }

    if (current.images.length != sample.images.length) {
      return true;
    }

    for (var index = 0; index < current.images.length; index++) {
      if (current.images[index] != sample.images[index]) {
        return true;
      }
    }

    return false;
  }

  Future<List<Pagoda>> getFavorites({required String ownerUserId}) {
    return _db.getFavorites(ownerUserId: ownerUserId);
  }

  Future<void> toggleFavorite(String pagodaId, {required String ownerUserId}) {
    return _db.toggleFavorite(pagodaId, ownerUserId: ownerUserId);
  }

  Future<void> replaceFavorites({
    required String ownerUserId,
    required Iterable<String> pagodaIds,
  }) {
    return _db.replaceFavorites(ownerUserId: ownerUserId, pagodaIds: pagodaIds);
  }

  Future<Pagoda?> getPagodaById(String id, {String? ownerUserId}) {
    return _db.getPagodaById(id, ownerUserId: ownerUserId);
  }
}
