import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('published route detail includes ratings and elevation profile', () {
    final detail = File('lib/features/discover/presentation/published_route_detail_screen.dart').readAsStringSync();
    final state = File('lib/app/app_state.dart').readAsStringSync();
    final models = File('lib/domain/models.dart').readAsStringSync();
    expect(detail, contains('Vurder turen'));
    expect(detail, contains('Høydeprofil'));
    expect(detail, contains('Kjør ruta'));
    expect(detail, contains('Open-Meteo / Copernicus DEM GLO-90'));
    expect(state, contains("'setRating'"));
    expect(state, contains("'/api/v1/map/elevation-profile'"));
    expect(models, contains('class RouteRating'));
    expect(models, contains('class ElevationProfile'));
  });
}
