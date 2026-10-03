import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/features/offline/domain/offline_catalog.dart';
import 'package:govia_mobile/features/offline/domain/offline_area.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('bundled catalog includes countries and named regional bounds', () async {
    final catalog = await loadOfflineCatalog();
    expect(catalog.length, greaterThan(200));
    final norway = catalog.singleWhere((c) => c.area.id == 'NOR');
    expect(norway.area.name, 'Norge');
    expect(norway.continent, 'Europa');
    expect(norway.regions, isNotEmpty);
    expect(catalog.map((c) => c.area.id).toSet().length, catalog.length);
    for (final country in catalog) {
      for (final entry in [country.area, ...country.regions]) {
        final area = entry.area;
        expect(area.valid, isTrue, reason: entry.id);
        expect(area.estimatedTiles, lessThanOrEqualTo(OfflineArea.maxTiles), reason: entry.id);
      }
    }
  });
  test('large bounds lower detail while retaining geographic extent', () {
    final entry = OfflineCatalogArea({'id': 'test', 'name': 'Område', 'bounds': [-10, 35, 30, 70]});
    expect(entry.area.maxZoom, lessThan(13));
    expect(entry.area.west, -10);
    expect(entry.area.north, 70);
    expect(entry.area.estimatedTiles, lessThanOrEqualTo(OfflineArea.maxTiles));
  });
}
