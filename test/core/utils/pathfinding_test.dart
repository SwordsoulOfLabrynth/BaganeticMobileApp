import 'package:baganetic_mobile/core/utils/pathfinding.dart';
import 'package:baganetic_mobile/data/models/pagoda_model.dart';
import 'package:flutter_test/flutter_test.dart';

Pagoda _pagoda(String id, double latitude, double longitude) {
  return Pagoda(
    id: id,
    name: id,
    description: '',
    category: 'Pagoda',
    latitude: latitude,
    longitude: longitude,
    imageUrl: '',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('river-crossing route constraint', () {
    test('marks Tant Kyi Taung as requiring a crossing', () async {
      final graph = await PathfindingService.loadGraph();

      expect(graph, isNotNull);
      expect(graph!.nodes['tantkyitaung']?.requiresRiverCrossing, isTrue);
      expect(
        PathfindingService.routeRequiresRiverCrossing(const [
          'ananda',
          'tantkyitaung',
        ], graph),
        isTrue,
      );
    });

    test('does not return a fictional road route across the river', () async {
      final ananda = _pagoda('ananda', 21.1719, 94.8585);
      final tantKyiTaung = _pagoda('tantkyitaung', 21.15527, 94.78786);

      final result = await PathfindingService.findPath(ananda, tantKyiTaung, [
        ananda,
        tantKyiTaung,
      ]);

      expect(result.requiresRiverCrossing, isTrue);
      expect(result.isEmpty, isTrue);
      expect(result.isRoadGraphRoute, isFalse);
    });

    test(
      'keeps the real mainland pagoda waypoints when planning a ferry route',
      () async {
        final graph = await PathfindingService.loadGraph();
        expect(graph, isNotNull);

        const routeIds = [
          'tuywintaung',
          'izagawna',
          'alodawpyae',
          'htilominlo',
          'ananda',
          'shwegugyi',
          'bupaya',
        ];
        final pagodas = routeIds
            .map((id) {
              final node = graph!.nodes[id]!;
              return _pagoda(id, node.lat, node.lng);
            })
            .toList(growable: false);

        final result = await PathfindingService.findPath(
          pagodas.first,
          pagodas.last,
          pagodas,
          requireTrustedRoadAccess: false,
        );

        expect(result.path.map((pagoda) => pagoda.id), routeIds);
        expect(result.roadNodePath, hasLength(routeIds.length));
        // Tuywin Taung is remote from the offline road mesh, so this route
        // is still shown as partial coverage rather than a false guarantee.
        expect(result.isRoadGraphRoute, isFalse);
      },
    );
  });
}
