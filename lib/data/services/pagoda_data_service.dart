import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/services/logger.dart';
import '../datasources/local_datasource.dart';
import '../models/pagoda_model.dart';

class PagodaDataService {
  PagodaDataService({DatabaseService? databaseService})
      : _db = databaseService ?? DatabaseService();

  final DatabaseService _db;

  Future<List<Pagoda>> loadPagodas() async {
    var pagodas = await _db.getAllPagodas();

    if (pagodas.isEmpty) {
      Logger.info('Database is empty, initializing with sample data...');
      await initializeSampleData();
      pagodas = await _db.getAllPagodas();
      Logger.info('Initialized ${pagodas.length} pagodas with sample data');
    } else if (pagodas.isNotEmpty) {
      final didRefresh = await _refreshFromSampleIfNeeded(pagodas);
      if (didRefresh) {
        pagodas = await _db.getAllPagodas();
        Logger.info('Refreshed pagoda data from sample JSON');
      }
      Logger.info('Loaded ${pagodas.length} pagodas from database');
    }

    return pagodas;
  }

  Future<void> reloadSampleData() async {
    await _db.clearAllData();
    await initializeSampleData();
  }

  Future<void> initializeSampleData() async {
    final samplePagodas = await _loadSamplePagodas();
    for (final pagoda in samplePagodas) {
      await _db.insertPagoda(pagoda);
    }
  }

  Future<List<Pagoda>> _loadSamplePagodas() async {
    final jsonString =
        await rootBundle.loadString('assets/data/sample_pagodas.json');
    final List<dynamic> jsonData = jsonDecode(jsonString) as List<dynamic>;
    return jsonData
        .map((item) => Pagoda.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<bool> _refreshFromSampleIfNeeded(List<Pagoda> existing) async {
    final samplePagodas = await _loadSamplePagodas();
    final Map<String, Pagoda> sampleById = {
      for (final pagoda in samplePagodas) pagoda.id: pagoda,
    };

    var updated = false;
    for (final pagoda in existing) {
      final sample = sampleById[pagoda.id];
      if (sample == null) continue;

      if (_needsRefresh(pagoda, sample)) {
        final merged = sample.copyWith(isFavorite: pagoda.isFavorite);
        await _db.insertPagoda(merged);
        updated = true;
      }
    }

    return updated;
  }

  bool _needsRefresh(Pagoda current, Pagoda sample) {
    bool missingOrEmpty(String? value, String? sampleValue) {
      if (sampleValue == null || sampleValue.trim().isEmpty) return false;
      return value == null || value.trim().isEmpty;
    }

    if (missingOrEmpty(current.historicalInfo, sample.historicalInfo) ||
        missingOrEmpty(current.architecturalStyle, sample.architecturalStyle) ||
        missingOrEmpty(current.legends, sample.legends) ||
        missingOrEmpty(
            current.religiousImportance, sample.religiousImportance) ||
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

    if (current.images.length < sample.images.length) {
      return true;
    }

    return false;
  }

  Future<List<Pagoda>> getFavorites() {
    return _db.getFavorites();
  }

  Future<void> toggleFavorite(String pagodaId) {
    return _db.toggleFavorite(pagodaId);
  }

  Future<Pagoda?> getPagodaById(String id) {
    return _db.getPagodaById(id);
  }
}
