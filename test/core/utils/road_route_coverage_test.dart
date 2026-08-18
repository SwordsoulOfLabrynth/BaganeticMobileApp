import 'dart:convert';

import 'package:baganetic_mobile/core/utils/pathfinding.dart';
import 'package:baganetic_mobile/data/models/pagoda_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<Pagoda>> _catalogPagodas() async {
  final raw = await rootBundle.loadString('assets/data/pagoda_route_graph.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return (data['nodes'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .map(
        (node) => Pagoda(
          id: node['pagodaId'] as String,
          name: node['name'] as String,
          description: '',
          category: 'Pagoda',
          latitude: (node['lat'] as num).toDouble(),
          longitude: (node['lng'] as num).toDouble(),
          imageUrl: '',
        ),
      )
      .toList(growable: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Lawkananda to Abeyadana keeps the curated road route', () async {
    final catalog = await _catalogPagodas();
    final byId = {for (final pagoda in catalog) pagoda.id: pagoda};
    final result = await PathfindingService.findPath(
      byId['lawkananda']!,
      byId['abeyadana']!,
      catalog,
    );

    expect(result.isRoadGraphRoute, isTrue);
    expect(result.path.map((pagoda) => pagoda.id), [
      'lawkananda',
      'seinnyetnyiama',
      'manuha',
      'abeyadana',
    ]);

    final rawOffline =
        await rootBundle.loadString('assets/data/offline_graph.json');
    final offline = jsonDecode(rawOffline) as Map<String, dynamic>;
    final offlineNodeIds = (offline['nodes'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((node) => node['id'] as String)
        .toSet();
    expect(
      result.roadNodePath.every(offlineNodeIds.contains),
      isTrue,
      reason: 'Each pagoda waypoint must resolve to a bundled road node.',
    );

    final adjacency = <String, Set<String>>{};
    for (final edge in (offline['edges'] as List<dynamic>)
        .cast<Map<String, dynamic>>()) {
      final from = edge['from'] as String;
      final to = edge['to'] as String;
      adjacency.putIfAbsent(from, () => <String>{}).add(to);
      if (edge['oneWay'] != true) {
        adjacency.putIfAbsent(to, () => <String>{}).add(from);
      }
    }

    final visited = <String>{result.roadNodePath.first};
    final pending = <String>[result.roadNodePath.first];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      for (final next in adjacency[current] ?? const <String>{}) {
        if (visited.add(next)) pending.add(next);
      }
    }
    expect(visited, contains(result.roadNodePath.last));
  });
}
