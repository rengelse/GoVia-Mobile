import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/route_profile_picker.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../domain/models.dart';
import '../../../domain/transport_profiles.dart';

class RoundTripScreen extends StatefulWidget {
  const RoundTripScreen({super.key});

  @override
  State<RoundTripScreen> createState() => _RoundTripScreenState();
}

class _RoundTripScreenState extends State<RoundTripScreen> {
  double km = 180;
  String direction = 'Fri';
  StageTransport transport = StageTransport.motorcycle;
  String profile = defaultProfileForTransport(StageTransport.motorcycle);
  GeoPoint? origin;
  String originLabel = 'Startpunkt ikke valgt';
  bool locating = false;
  bool generating = false;
  List<RouteCandidate> candidates = const [];
  List<GeoPoint> preview = const [];

  @override
  Widget build(BuildContext context) => GoViaScreen(
        title: 'Opprett rundtur',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RouteMapCard(
              key: ValueKey(preview.isNotEmpty ? _geometryKey(preview) : '${origin?.lat},${origin?.lon}'),
              height: 250,
              points: preview.isNotEmpty ? preview : [if (origin != null) origin!],
              connectPoints: preview.isNotEmpty,
              label: preview.isNotEmpty ? 'Rundtur' : 'Velg startpunkt',
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.my_location, color: GoViaColors.cyan),
                title: const Text('Startpunkt', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(originLabel),
                trailing: locating
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(onPressed: _useCurrentLocation, tooltip: 'Bruk min posisjon', icon: const Icon(Icons.location_on_outlined)),
                onTap: locating ? null : _useCurrentLocation,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<StageTransport>(
              initialValue: transport,
              decoration: const InputDecoration(labelText: 'Transporttype'),
              items: [
                for (final value in roundTripTransports)
                  DropdownMenuItem(value: value, child: Text(transportLabel(value))),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  transport = value;
                  profile = defaultProfileForTransport(value);
                  candidates = const [];
                  preview = const [];
                });
              },
            ),
            const SizedBox(height: 14),
            Text('Ønsket lengde: ${km.round()} km', style: const TextStyle(fontWeight: FontWeight.w800)),
            Slider(value: km, min: 10, max: 600, divisions: 59, label: '${km.round()} km', onChanged: (value) => setState(() => km = value)),
            DropdownButtonFormField<String>(
              initialValue: direction,
              decoration: const InputDecoration(labelText: 'Retning'),
              items: const ['Fri', 'Nord', 'Sør', 'Øst', 'Vest', 'Tilfeldig'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) => setState(() => direction = value ?? direction),
            ),
            const SizedBox(height: 10),
            RouteProfilePicker(
              transport: transport,
              value: profile,
              onChanged: (value) => setState(() {
                profile = value;
                candidates = const [];
                preview = const [];
              }),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: generating ? null : _generate,
              icon: generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.loop),
              label: Text(generating ? 'Genererer…' : 'Generer rundtur'),
            ),
            if (candidates.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionTitle('Rundturalternativer'),
              for (var index = 0; index < candidates.length; index++)
                Card(
                  child: ListTile(
                    onTap: () => setState(() => preview = candidates[index].geometry),
                    leading: Icon(_sameGeometry(preview, candidates[index].geometry) ? Icons.radio_button_checked : Icons.radio_button_off, color: _sameGeometry(preview, candidates[index].geometry) ? GoViaColors.orange : GoViaColors.muted),
                    title: Text(candidates[index].name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${(candidates[index].distanceMeters / 1000).round()} km · ${_duration(candidates[index].durationSeconds)}'),
                    trailing: FilledButton(onPressed: () => _save(candidates[index]), child: const Text('Velg')),
                  ),
                ),
            ],
          ],
        ),
      );

  Future<void> _useCurrentLocation() async {
    setState(() => locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw StateError('Posisjonstjenester er slått av.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw StateError('GoVia har ikke tilgang til posisjonen din.');
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (!mounted) return;
      setState(() {
        origin = GeoPoint(lat: position.latitude, lon: position.longitude, label: 'Min posisjon');
        originLabel = 'Min posisjon';
        candidates = const [];
        preview = const [];
      });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> _generate() async {
    if (origin == null) {
      await _useCurrentLocation();
      if (!mounted || origin == null) return;
    }
    setState(() {
      generating = true;
      candidates = const [];
      preview = const [];
    });
    try {
      final response = await AppScope.of(context).api.postJson('/api/v1/map/roundtrip', {
        'origin': {
          'coord': [origin!.lon, origin!.lat],
          'name': originLabel,
        },
        'mode': routeModeForTransport(transport),
        'targetDistanceMeters': (km * 1000).round(),
        'direction': direction,
        'profile': profile,
      });
      final data = response['data'];
      if (data is! Map) throw StateError('Ugyldig svar fra rundturgeneratoren.');
      final rows = <Map<String, dynamic>>[
        Map<String, dynamic>.from(data),
        ...((data['alternatives'] as List? ?? const []).whereType<Map>().map((value) => Map<String, dynamic>.from(value))),
      ];
      final parsed = <RouteCandidate>[];
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        final geometry = (row['geometry'] as List? ?? const [])
            .whereType<List>()
            .where((point) => point.length >= 2 && point[0] is num && point[1] is num)
            .map((point) => GeoPoint(lon: (point[0] as num).toDouble(), lat: (point[1] as num).toDouble()))
            .toList(growable: false);
        if (geometry.length < 2) continue;
        parsed.add(RouteCandidate(
          id: 'roundtrip-${DateTime.now().microsecondsSinceEpoch}-$index',
          name: index == 0 ? 'Anbefalt' : 'Alternativ $index',
          distanceMeters: (row['distance'] as num? ?? 0).round(),
          durationSeconds: (row['duration'] as num? ?? 0).round(),
          geometry: geometry,
          maneuvers: (row['maneuvers'] as List? ?? const [])
              .whereType<Map>()
              .map((value) => NavigationManeuver.fromJson(Map<String, dynamic>.from(value)))
              .toList(growable: false),
          guidanceSource: row['guidanceSource']?.toString() ?? 'none',
        ));
      }
      if (parsed.isEmpty) throw StateError('Serveren returnerte ingen kjørbar rundtur.');
      if (!mounted) return;
      setState(() {
        candidates = parsed;
        preview = parsed.first.geometry;
      });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rundtur feilet: $error')));
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> _save(RouteCandidate route) async {
    final now = DateTime.now();
    final label = originLabel == 'Startpunkt ikke valgt' ? 'Start' : originLabel;
    final stage = Stage(
      id: 'roundtrip-stage-${now.microsecondsSinceEpoch}',
      day: 0,
      order: 0,
      start: label,
      end: label,
      transport: transport,
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
      routeCandidates: [
        for (final candidate in candidates) candidate.copyWith(official: candidate.id == route.id),
      ],
      officialRouteId: route.id,
      routeProfile: profile,
    );
    final trip = Trip(
      id: 'roundtrip-trip-${now.microsecondsSinceEpoch}',
      name: 'Rundtur · ${(route.distanceMeters / 1000).round()} km',
      startDate: now,
      endDate: now,
      start: label,
      end: label,
      status: TripStatus.planned,
      stages: [stage],
    );
    await AppScope.of(context).addLocalTrip(trip);
    if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.trip, arguments: trip);
  }

  bool _sameGeometry(List<GeoPoint> a, List<GeoPoint> b) => a.isNotEmpty && b.isNotEmpty && a.length == b.length && a.first.lat == b.first.lat && a.first.lon == b.first.lon && a.last.lat == b.last.lat && a.last.lon == b.last.lon;
  String _geometryKey(List<GeoPoint> values) => values.map((value) => '${value.lat.toStringAsFixed(5)},${value.lon.toStringAsFixed(5)}').join('|');
  String _duration(int seconds) {
    final minutes = (seconds / 60).round();
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return hours > 0 ? '${hours}t ${rest}m' : '${rest}m';
  }
}
