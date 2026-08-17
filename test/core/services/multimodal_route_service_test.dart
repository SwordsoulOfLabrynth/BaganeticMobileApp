import 'package:baganetic_mobile/core/services/multimodal_route_service.dart';
import 'package:baganetic_mobile/data/models/pagoda_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the curated Bu Paya to Tant Kyi ferry connection', () async {
    final connection = await MultimodalRouteService.instance
        .connectionForPagoda('tantkyitaung');

    expect(connection, isNotNull);
    expect(connection!.originTerminal.name, 'Bu Paya Jetty');
    expect(connection.destinationTerminal.name, 'Tant Kyi motor jetty');
    expect(connection.mainlandPagodaId, 'bupaya');
    expect(connection.ferryRouteGeometry, hasLength(8));
    expect(connection.ferryPoints, hasLength(8));
    expect(
      connection.ferryRouteGeometry[4].longitude,
      closeTo(94.8317760, 0.000001),
    );
    expect(
      connection.originTerminal.location.latitude,
      closeTo(21.1762808, 0.000001),
    );
    expect(
      connection.destinationTerminal.location.longitude,
      closeTo(94.8050232, 0.000001),
    );
    expect(
      await MultimodalRouteService.instance.routeUsesFerry(const [
        'ananda',
        'tantkyitaung',
      ]),
      isTrue,
    );
  });

  test('ferry path steps include terminals and mainland waypoints', () {
    final start = Pagoda(
      id: 'minochantha',
      name: 'Minochantha',
      description: '',
      category: 'Pagoda',
      latitude: 21.17,
      longitude: 94.86,
      imageUrl: '',
    );
    final gateway = Pagoda(
      id: 'bupaya',
      name: 'Bu Paya',
      description: '',
      category: 'Pagoda',
      latitude: 21.176,
      longitude: 94.857,
      imageUrl: '',
    );
    final end = Pagoda(
      id: 'tantkyitaung',
      name: 'Tant Kyi Taung Pagoda',
      description: '',
      category: 'Pagoda',
      latitude: 21.155,
      longitude: 94.788,
      imageUrl: '',
    );
    const connection = FerryConnection(
      id: 'bupaya-tantkyi',
      pagodaId: 'tantkyitaung',
      mainlandPagodaId: 'bupaya',
      originTerminal: FerryTerminal(
        name: 'Bu Paya Jetty',
        nameMyanmar: 'ဗူးဘုရား လှေဆိပ်',
        location: LatLng(21.1762808, 94.8571698),
      ),
      destinationTerminal: FerryTerminal(
        name: 'Tant Kyi motor jetty',
        nameMyanmar: 'တန့်ကြည့် မော်တော်ဆိပ်',
        location: LatLng(21.1555755, 94.8050232),
      ),
      ferryRouteGeometry: [],
      availabilityNote: '',
      availabilityNoteMyanmar: '',
    );

    final steps = MultimodalRouteService.buildFerryPathSteps(
      start: start,
      end: end,
      connection: connection,
      mainlandPath: [start, gateway],
    );

    expect(steps.map((step) => step.id), [
      'minochantha',
      'bupaya',
      'bupaya-tantkyi-east',
      'bupaya-tantkyi-west',
      'tantkyitaung',
    ]);
    expect(steps.where((step) => step.isFerryTerminal), hasLength(2));
  });
}
