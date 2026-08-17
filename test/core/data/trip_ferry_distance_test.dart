import 'package:baganetic_mobile/core/services/multimodal_route_service.dart';
import 'package:baganetic_mobile/core/utils/pathfinding.dart';
import 'package:baganetic_mobile/data/models/pagoda_model.dart';
import 'package:baganetic_mobile/data/models/trip_model.dart';
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

TripStop _stop({
  required String pagodaId,
  required double latitude,
  required double longitude,
  required int order,
  double? distanceToNext,
}) {
  return TripStop(
    pagodaId: pagodaId,
    pagodaName: pagodaId,
    latitude: latitude,
    longitude: longitude,
    order: order,
    distanceToNext: distanceToNext,
  );
}

Trip _tripWithStops(
  List<TripStop> stops, {
  TripTransportMode mode = TripTransportMode.bike,
}) {
  final now = DateTime.now();
  return Trip(
    id: 't_${now.millisecondsSinceEpoch}',
    ownerUserId: 'u1',
    name: 'Test Trip',
    transportMode: mode,
    date: now,
    stops: stops,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ananda = _pagoda('ananda', 21.1719, 94.8585);
  final bupaya = _pagoda('bupaya', 21.1763128, 94.857903);
  final tantKyiTaung = _pagoda('tantkyitaung', 21.15527, 94.78786);
  final shwezigon = _pagoda('shwezigon', 21.1843, 94.8610);
  final thatbyinnyu = _pagoda('thatbyinnyu', 21.1755, 94.8545);

  group('Trip.getTotalDistance - post-fix correctness', () {
    test('returns 0 for fewer than 2 stops', () {
      final trip0 = _tripWithStops([]);
      final trip1 = _tripWithStops([
        _stop(pagodaId: 'a', latitude: 0, longitude: 0, order: 0, distanceToNext: 5),
      ]);
      expect(trip0.getTotalDistance(), 0);
      expect(trip1.getTotalDistance(), 0);
    });

    test('sums stored distances correctly (3 road stops)', () {
      final trip = _tripWithStops([
        _stop(pagodaId: ananda.id, latitude: ananda.latitude, longitude: ananda.longitude, order: 0, distanceToNext: 1.5),
        _stop(pagodaId: thatbyinnyu.id, latitude: thatbyinnyu.latitude, longitude: thatbyinnyu.longitude, order: 1, distanceToNext: 2.25),
        _stop(pagodaId: shwezigon.id, latitude: shwezigon.latitude, longitude: shwezigon.longitude, order: 2),
      ]);
      expect(trip.getTotalDistance(), closeTo(3.75, 0.001));
    });

    test('FALLBACK: sums haversine between coords when stored distances are ALL null',
        () {
      // This is the QA bug: all ferry legs stored distanceToNext=null.
      // Before fix: getTotalDistance returned 0 (H1 confirmed evidence).
      // After fix: getLegDistance falls back to haversine, so total is > 0.
      final trip = _tripWithStops([
        _stop(
          pagodaId: ananda.id,
          latitude: ananda.latitude,
          longitude: ananda.longitude,
          order: 0,
          distanceToNext: null,
        ),
        _stop(
          pagodaId: tantKyiTaung.id,
          latitude: tantKyiTaung.latitude,
          longitude: tantKyiTaung.longitude,
          order: 1,
          distanceToNext: null,
        ),
      ]);
      final total = trip.getTotalDistance();
      expect(total, greaterThan(1.0));
      // Ananda (21.1719, 94.8585) -> Tant Kyi (21.15527, 94.78786)
      // Expected haversine ~7.5 km.
      expect(total, closeTo(7.5, 2.0));
    });

    test('FALLBACK: mixed stored and null (legacy data) uses correct strategy',
        () {
      // Stop 0 -> 1 uses stored 2.5
      // Stop 1 -> 2 uses haversine fallback (distanceToNext null)
      const legA = 2.5;
      final trip = _tripWithStops([
        _stop(pagodaId: ananda.id, latitude: ananda.latitude, longitude: ananda.longitude, order: 0, distanceToNext: legA),
        _stop(pagodaId: bupaya.id, latitude: bupaya.latitude, longitude: bupaya.longitude, order: 1, distanceToNext: null),
        _stop(pagodaId: tantKyiTaung.id, latitude: tantKyiTaung.latitude, longitude: tantKyiTaung.longitude, order: 2),
      ]);
      final total = trip.getTotalDistance();
      expect(total, greaterThan(legA));
      // Bu Paya -> Tant Kyi is at least 2 km by river.
      expect(total, greaterThan(legA + 1.0));
    });
  });

  group('Trip.getLegDistance - fallback semantics', () {
    test('prefers stored distance over haversine when both available', () {
      final trip = _tripWithStops([
        _stop(pagodaId: ananda.id, latitude: ananda.latitude, longitude: ananda.longitude, order: 0, distanceToNext: 99.99),
        _stop(pagodaId: shwezigon.id, latitude: shwezigon.latitude, longitude: shwezigon.longitude, order: 1),
      ]);
      // Should use stored 99.99, not real haversine (~1-2 km)
      expect(trip.getLegDistance(0), closeTo(99.99, 0.001));
    });

    test('uses haversine when stored distance is null (QA fix)', () {
      final trip = _tripWithStops([
        _stop(pagodaId: ananda.id, latitude: ananda.latitude, longitude: ananda.longitude, order: 0, distanceToNext: null),
        _stop(pagodaId: shwezigon.id, latitude: shwezigon.latitude, longitude: shwezigon.longitude, order: 1),
      ]);
      final leg = trip.getLegDistance(0);
      // Ananda-Shwezigon: ~1.4 km by haversine
      expect(leg, greaterThan(0.5));
      expect(leg, lessThan(5.0));
    });

    test('returns 0 for out-of-range or last-stop index', () {
      final trip = _tripWithStops([
        _stop(pagodaId: 'a', latitude: 0, longitude: 0, order: 0, distanceToNext: 3),
        _stop(pagodaId: 'b', latitude: 0.01, longitude: 0.01, order: 1),
      ]);
      expect(trip.getLegDistance(-1), 0);
      expect(trip.getLegDistance(1), 0); // last
      expect(trip.getLegDistance(99), 0);
    });
  });

  group('Trip.getEstimatedTravelDuration', () {
    test('bike mode 15 km/h over 30 km -> ~120 minutes', () {
      final trip = _tripWithStops(
        [
          _stop(pagodaId: 'a', latitude: 0, longitude: 0, order: 0, distanceToNext: 30),
          _stop(pagodaId: 'b', latitude: 0.2, longitude: 0.2, order: 1),
        ],
        mode: TripTransportMode.bike,
      );
      expect(trip.getEstimatedTravelDuration(), closeTo(120, 1));
    });

    test('walk mode 5 km/h over 5 km -> ~60 minutes', () {
      final trip = _tripWithStops(
        [
          _stop(pagodaId: 'a', latitude: 0, longitude: 0, order: 0, distanceToNext: 5),
          _stop(pagodaId: 'b', latitude: 0.05, longitude: 0.05, order: 1),
        ],
        mode: TripTransportMode.walk,
      );
      expect(trip.getEstimatedTravelDuration(), closeTo(60, 1));
    });

    test('uses fixed distances (fallback) when stored null for ferry trip',
        () {
      // Before fix: duration was 0 minutes because getTotalDistance was 0.
      // After fix: haversine fallback gives non-zero total.
      final trip = _tripWithStops(
        [
          _stop(pagodaId: bupaya.id, latitude: bupaya.latitude, longitude: bupaya.longitude, order: 0),
          _stop(pagodaId: tantKyiTaung.id, latitude: tantKyiTaung.latitude, longitude: tantKyiTaung.longitude, order: 1),
        ],
        mode: TripTransportMode.bike,
      );
      final durationMin = trip.getEstimatedTravelDuration();
      expect(trip.getTotalDistance(), greaterThan(1.0));
      expect(durationMin, greaterThan(0));
    });
  });

  group('Regression: ferry detection predicates agree', () {
    test('bupaya <-> tantkyitaung pair detected as ferry by BOTH services',
        () async {
      final graph = await PathfindingService.loadGraph();
      final byPathfinding = PathfindingService.requiresRiverCrossingBetween(
        bupaya.id,
        tantKyiTaung.id,
        graph,
      );
      final byMultimodal =
          await MultimodalRouteService.instance.routeUsesFerry([
        bupaya.id,
        tantKyiTaung.id,
      ]);
      expect(byPathfinding, isTrue);
      expect(byMultimodal, isTrue);
    });

    test('ananda <-> shwezigon (both mainland) NOT detected as ferry',
        () async {
      final graph = await PathfindingService.loadGraph();
      final byPathfinding = PathfindingService.requiresRiverCrossingBetween(
        ananda.id,
        shwezigon.id,
        graph,
      );
      final byMultimodal =
          await MultimodalRouteService.instance.routeUsesFerry([
        ananda.id,
        shwezigon.id,
      ]);
      expect(byPathfinding, isFalse);
      expect(byMultimodal, isFalse);
    });
  });

  group('Regression: PathfindingService.riverCrossing constraint', () {
    test('tantkyitaung node still flagged requiresRiverCrossing', () async {
      final graph = await PathfindingService.loadGraph();
      expect(graph, isNotNull);
      expect(graph!.nodes['tantkyitaung']?.requiresRiverCrossing, isTrue);
    });

    test('findPath refuses fictional road across river (A* returns riverCrossing)',
        () async {
      final pagodas = [ananda, tantKyiTaung];
      final result = await PathfindingService.findPath(
        ananda,
        tantKyiTaung,
        pagodas,
      );
      expect(result.requiresRiverCrossing, isTrue);
      expect(result.isEmpty, isTrue);
    });
  });

  group('Regression: MultimodalRouteService ferry connection loads', () {
    test('connectionForPagoda(tantkyitaung) returns curated Bu Paya link',
        () async {
      final connection = await MultimodalRouteService.instance
          .connectionForPagoda('tantkyitaung');
      expect(connection, isNotNull);
      expect(connection!.originTerminal.name, 'Bu Paya Jetty');
      expect(connection.destinationTerminal.name, 'Tant Kyi motor jetty');
      expect(connection.ferryRouteGeometry, isNotEmpty);
    });
  });
}
