import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../domain/models.dart';

class PlaceSuggestion {
  const PlaceSuggestion({required this.label, required this.point});

  final String label;
  final GeoPoint point;
  List<double> get coord => [point.lon, point.lat];
}

class PlaceSearchService {
  static Future<List<PlaceSuggestion>> search(String query) async {
    final response = await http.get(
      Uri.https('photon.komoot.io', '/api/', {'q': query, 'limit': '6'}),
      headers: const {
        'Accept': 'application/json',
        'Accept-Language': 'nb-NO,nb;q=0.9,no;q=0.8,en;q=0.7',
        'User-Agent': 'GoVia-Mobile/1.0 (place-search)',
      },
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    return parse(jsonDecode(response.body));
  }

  static List<PlaceSuggestion> parse(dynamic response) {
    if (response is! Map) return const [];
    final features = response['features'];
    if (features is! List) return const [];
    final result = <PlaceSuggestion>[];
    final seen = <String>{};
    for (final feature in features.whereType<Map>()) {
      final geometry = feature['geometry'];
      if (geometry is! Map) continue;
      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2 || coords[0] is! num || coords[1] is! num) continue;
      final lon = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      if (!lon.isFinite || !lat.isFinite || lon.abs() > 180 || lat.abs() > 90) continue;
      final properties = feature['properties'] is Map ? feature['properties'] as Map : const {};
      final street = properties['street']?.toString().trim() ?? '';
      final houseNumber = properties['housenumber']?.toString().trim() ?? '';
      final streetAddress = [street, houseNumber].where((value) => value.isNotEmpty).join(' ');
      final parts = <String>[
        properties['name']?.toString() ?? streetAddress,
        if ((properties['name']?.toString().trim().isNotEmpty ?? false) && streetAddress.isNotEmpty) streetAddress,
        properties['city']?.toString() ?? properties['town']?.toString() ?? properties['village']?.toString() ?? properties['locality']?.toString() ?? '',
        properties['state']?.toString() ?? '',
        properties['country']?.toString() ?? '',
      ].where((value) => value.trim().isNotEmpty).map((value) => value.trim()).toList();
      final unique = <String>[];
      for (final part in parts) {
        if (unique.isEmpty || unique.last.toLowerCase() != part.toLowerCase()) unique.add(part);
      }
      final label = unique.isNotEmpty ? unique.join(', ') : '${(coords[1] as num).toStringAsFixed(5)}, ${(coords[0] as num).toStringAsFixed(5)}';
      final key = '${label.toLowerCase()}|${coords[0]}|${coords[1]}';
      if (!seen.add(key)) continue;
      result.add(PlaceSuggestion(point: GeoPoint(lat: (coords[1] as num).toDouble(), lon: (coords[0] as num).toDouble()), label: label));
      if (result.length >= 6) break;
    }
    return result;
  }

}
