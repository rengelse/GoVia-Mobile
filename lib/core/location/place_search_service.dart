import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/models.dart';

class PlaceSearchResult {
  const PlaceSearchResult({required this.label, required this.point});

  final String label;
  final GeoPoint point;
}

class PlaceSearchService {
  const PlaceSearchService();

  Future<List<PlaceSearchResult>> search(String query, {int limit = 6}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': trimmed,
      'limit': '$limit',
    });
    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'Accept-Language': 'nb-NO,nb;q=0.9,no;q=0.8,en;q=0.7',
        'User-Agent': 'GoVia-Mobile/1.0 (place-search)',
      },
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    return parsePhoton(jsonDecode(response.body), limit: limit);
  }

  List<PlaceSearchResult> parsePhoton(dynamic response, {int limit = 6}) {
    if (response is! Map) return const [];
    final features = response['features'];
    if (features is! List) return const [];

    final result = <PlaceSearchResult>[];
    final seen = <String>{};
    for (final feature in features.whereType<Map>()) {
      final geometry = feature['geometry'];
      if (geometry is! Map) continue;
      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2 || coords[0] is! num || coords[1] is! num) continue;
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
      ].where((value) => value.trim().isNotEmpty).map((value) => value.trim()).toList(growable: false);

      final unique = <String>[];
      for (final part in parts) {
        if (unique.isEmpty || unique.last.toLowerCase() != part.toLowerCase()) unique.add(part);
      }
      final label = unique.isNotEmpty
          ? unique.join(', ')
          : '${(coords[1] as num).toStringAsFixed(5)}, ${(coords[0] as num).toStringAsFixed(5)}';
      final key = '${label.toLowerCase()}|${coords[0]}|${coords[1]}';
      if (!seen.add(key)) continue;
      result.add(PlaceSearchResult(
        label: label,
        point: GeoPoint(lat: (coords[1] as num).toDouble(), lon: (coords[0] as num).toDouble()),
      ));
      if (result.length >= limit) break;
    }
    return result;
  }
}
