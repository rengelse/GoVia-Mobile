import 'dart:convert';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../domain/models.dart';
import '../data/map_place_repository.dart';

class MapRouteOverlay {
  const MapRouteOverlay({required this.id, required this.geometry, required this.color, this.target});
  final String id;
  final List<GeoPoint> geometry;
  final String color;
  final Object? target;
}

// Only the home-map preview is sampled; canonical/navigation geometry stays intact.
List<GeoPoint> mapPreviewGeometry(List<GeoPoint> source) {
  if (source.length <= 250) return source;
  return [for (var i = 0; i < 250; i++) source[(i * (source.length - 1) / 249).round()]];
}

class MapOverlayRenderer {
  MapLibreMapController? _controller;
  int _epoch = 0;
  bool _drawing = false;
  String? _signature;
  ({List<MapRouteOverlay> routes, List<MapPlace> places})? _wanted;
  final Map<String, Object> targets = {};

  void attach(MapLibreMapController controller) {
    _epoch++;
    _controller = controller;
    _signature = null;
    targets.clear();
  }

  void detach() { _epoch++; _controller = null; _signature = null; targets.clear(); }

  Future<void> render(List<MapRouteOverlay> routes, List<MapPlace> places) async {
    _wanted = (routes: routes, places: places);
    if (_drawing || _controller == null) return;
    _drawing = true;
    try {
      while (_wanted != null && _controller != null) {
        final input = _wanted!;
        _wanted = null;
        final controller = _controller!;
        final epoch = _epoch;
        final previews = [for (final route in input.routes) mapPreviewGeometry(route.geometry)];
        final signature = jsonEncode([
          for (var i = 0; i < input.routes.length; i++) [input.routes[i].id, input.routes[i].color,
            for (final p in previews[i]) [p.lon, p.lat]],
          for (final place in input.places) [place.id, place.point.lon, place.point.lat],
        ]);
        if (_signature == signature) continue;
        try {
          await controller.clearLines();
          if (epoch != _epoch) continue;
          await controller.clearCircles();
          if (epoch != _epoch) continue;
          targets.clear();
          for (var i = 0; i < input.routes.length; i++) {
            if (epoch != _epoch) break;
            final route = input.routes[i];
            final geometry = previews[i];
            if (geometry.length < 2) continue;
            await controller.addLine(LineOptions(
              geometry: [for (final p in geometry) LatLng(p.lat, p.lon)],
              lineColor: route.color, lineWidth: route.color == '#FF7A21' ? 5.5 : 3.5, lineOpacity: .9));
            if (epoch != _epoch) break;
            if (route.target != null) {
              final circle = await controller.addCircle(CircleOptions(
                geometry: LatLng(geometry.first.lat, geometry.first.lon), circleColor: route.color,
                circleRadius: 7, circleStrokeColor: '#FFFFFF', circleStrokeWidth: 2));
              if (epoch == _epoch) targets[circle.id] = route.target!;
            }
          }
          for (final place in input.places) {
            if (epoch != _epoch) break;
            final circle = await controller.addCircle(CircleOptions(
              geometry: LatLng(place.point.lat, place.point.lon), circleColor: '#FF7A21',
              circleRadius: 7, circleStrokeColor: '#FFFFFF', circleStrokeWidth: 2));
            if (epoch == _epoch) targets[circle.id] = place;
          }
          if (epoch == _epoch) _signature = signature;
        } catch (_) {
          // Style/controller replacement invalidates native annotations. The next
          // style-loaded callback attaches a new epoch and redraws the latest input.
          if (epoch == _epoch) _signature = null;
        }
      }
    } finally { _drawing = false; }
  }
}
