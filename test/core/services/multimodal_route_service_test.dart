import 'package:baganetic_mobile/core/services/multimodal_route_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the curated Bu Paya to Tant Kyi ferry connection', () async {
    final connection = await MultimodalRouteService.instance
        .connectionForPagoda('tantkyitaung');

    expect(connection, isNotNull);
    expect(connection!.originTerminal.name, 'Bu Paya Jetty');
    expect(connection.destinationTerminal.name, 'Tant Kyi motor jetty');
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
}
