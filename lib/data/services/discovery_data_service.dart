import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/services/logger.dart';
import '../models/discovery_item.dart';

class DiscoveryDataService {
  Future<List<DiscoveryItem>> loadItems() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/sample_discovery.json');
      final List<dynamic> jsonData = jsonDecode(jsonString) as List<dynamic>;
      return jsonData
          .map((item) => DiscoveryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      Logger.error('Error loading discovery data', e, stackTrace);
      return [];
    }
  }
}
