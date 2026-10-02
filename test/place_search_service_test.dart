import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/features/new_trip/data/place_search_service.dart';

void main() {
  test('places retain coordinates, deduplicate and reject invalid geometry', () {
    Map<String, dynamic> feature(List<num> coordinates) => {
      'geometry': {'coordinates': coordinates},
      'properties': {'street': 'Bryggen', 'housenumber': '1', 'city': 'Bergen'},
    };
    final places = PlaceSearchService.parse({'features': [
      feature([5.32, 60.39]), feature([5.32, 60.39]), feature([200, 60]),
      feature([5, double.nan]), {'geometry': {'coordinates': ['bad', 60]}},
    ]});
    expect(places, hasLength(1));
    expect(places.single.label, 'Bryggen 1, Bergen');
    expect(places.single.point.lat, 60.39);
    expect(places.single.coord, [5.32, 60.39]);
    expect(PlaceSearchService.parse({'features': 'bad'}), isEmpty);
  });
}
