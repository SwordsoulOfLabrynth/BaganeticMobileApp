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
  });
}
