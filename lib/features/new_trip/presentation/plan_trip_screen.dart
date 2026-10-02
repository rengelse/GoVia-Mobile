import 'dart:async';
import 'dart:math' as math;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../data/place_search_service.dart';
import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/route_profile_picker.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../domain/models.dart';
import '../../../domain/transport_profiles.dart';

class PlanTripScreen extends StatefulWidget {
  const PlanTripScreen({super.key, this.destination});
  final PlaceSuggestion? destination;

  @override
  State<PlanTripScreen> createState() => _PlanTripScreenState();
}

class _PlanTripScreenState extends State<PlanTripScreen> {
  final start = TextEditingController();
  final end = TextEditingController();
  final via = TextEditingController();

  PlaceSuggestion? selectedStart;
  PlaceSuggestion? selectedVia;
  PlaceSuggestion? selectedEnd;
  StageTransport transport = StageTransport.motorcycle;
  String profile = defaultProfileForTransport(StageTransport.motorcycle);
  RoutePreferences routePreferences = const RoutePreferences();
  bool calculating = false;
  List<RouteCandidate> candidates = const [];
  List<GeoPoint> previewGeometry = const [];
  String? selectedRouteId;

  @override
  void initState() {
    super.initState();
    selectedEnd = widget.destination;
    end.text = widget.destination?.label ?? '';
  }

  @override
  void dispose() {
    start.dispose();
    end.dispose();
    via.dispose();
    super.dispose();
  }

  List<GeoPoint> get _selectedMapPoints {
    if (previewGeometry.isNotEmpty) return previewGeometry;
    return [
      if (selectedStart != null) selectedStart!.point,
      if (selectedVia != null) selectedVia!.point,
      if (selectedEnd != null) selectedEnd!.point,
    ];
  }

  String get _mapKey => _selectedMapPoints.map((e) => '${e.lat.toStringAsFixed(5)},${e.lon.toStringAsFixed(5)}').join('|');

  @override
  Widget build(BuildContext context) => GoViaScreen(
        title: 'Planlegg tur',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RouteMapCard(
              key: ValueKey(_mapKey),
              height: 250,
              points: _selectedMapPoints,
              connectPoints: previewGeometry.isNotEmpty,
              label: previewGeometry.isNotEmpty ? 'Forhåndsvisning' : 'Velg start og mål',
            ),
            const SizedBox(height: 16),
            _PlaceSearchField(
              controller: start,
              label: 'Startsted',
              icon: Icons.trip_origin,
              selected: selectedStart,
              onUseCurrentLocation: _useCurrentLocation,
              onSelected: (place) => setState(() {
                selectedStart = place;
                candidates = const [];
                previewGeometry = const [];
                selectedRouteId = null;
                selectedRouteId = null;
              }),
              onInvalidated: () => setState(() {
                selectedStart = null;
                candidates = const [];
                previewGeometry = const [];
                selectedRouteId = null;
                selectedRouteId = null;
              }),
            ),
            const SizedBox(height: 10),
            _PlaceSearchField(
              controller: via,
              label: 'Stopp / via (valgfritt)',
              icon: Icons.add_location_alt_outlined,
              selected: selectedVia,
              optional: true,
              onSelected: (place) => setState(() {
                selectedVia = place;
                candidates = const [];
                previewGeometry = const [];
                selectedRouteId = null;
                selectedRouteId = null;
              }),
              onInvalidated: () => setState(() {
                selectedVia = null;
                candidates = const [];
                previewGeometry = const [];
                selectedRouteId = null;
                selectedRouteId = null;
              }),
            ),
            const SizedBox(height: 10),
            _PlaceSearchField(
              controller: end,
              label: 'Mål',
              icon: Icons.flag_outlined,
              selected: selectedEnd,
              onSelected: (place) => setState(() {
                selectedEnd = place;
                candidates = const [];
                previewGeometry = const [];
                selectedRouteId = null;
                selectedRouteId = null;
              }),
              onInvalidated: () => setState(() {
                selectedEnd = null;
                candidates = const [];
                previewGeometry = const [];
                selectedRouteId = null;
                selectedRouteId = null;
              }),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<StageTransport>(
              initialValue: transport,
              decoration: const InputDecoration(labelText: 'Transporttype', prefixIcon: Icon(Icons.directions)),
              items: [
                for (final value in primaryTripTransports)
                  DropdownMenuItem(value: value, child: Text(transportLabel(value))),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  transport = value;
                  profile = defaultProfileForTransport(value);
                  routePreferences = const RoutePreferences();
                  candidates = const [];
                  previewGeometry = const [];
                  selectedRouteId = null;
                });
              },
            ),
            const SizedBox(height: 10),
            RouteProfilePicker(
              transport: transport,
              value: profile,
              onChanged: (value) => setState(() {
                profile = value;
                if (candidates.isNotEmpty) {
                  candidates = _rankCandidates(candidates, value);
                  previewGeometry = candidates.first.geometry;
                }
              }),
            ),
            const SizedBox(height: 10),
            if (getTransportUsesRoadCandidates(transport)) ...[
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: const Text('Ruteinnstillinger', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Unngå eller foretrekk bestemte veityper og omgivelser.'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _preferenceChip('Unngå motorvei', routePreferences.avoidMotorways, (v) => routePreferences = routePreferences.copyWith(avoidMotorways: v)),
                        _preferenceChip('Unngå bom', routePreferences.avoidTolls, (v) => routePreferences = routePreferences.copyWith(avoidTolls: v)),
                        _preferenceChip('Unngå ferge', routePreferences.avoidFerries, (v) => routePreferences = routePreferences.copyWith(avoidFerries: v)),
                        _preferenceChip('Unngå grus', routePreferences.avoidUnpaved, (v) => routePreferences = routePreferences.copyWith(avoidUnpaved: v)),
                        _preferenceChip('Unngå by', routePreferences.avoidCities, (v) => routePreferences = routePreferences.copyWith(avoidCities: v)),
                        _preferenceChip('Scenic', routePreferences.preferScenic, (v) => routePreferences = routePreferences.copyWith(preferScenic: v)),
                        _preferenceChip('Kystvei', routePreferences.preferCoastal, (v) => routePreferences = routePreferences.copyWith(preferCoastal: v)),
                        _preferenceChip('Fjellvei', routePreferences.preferMountains, (v) => routePreferences = routePreferences.copyWith(preferMountains: v)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline),
              title: Text('Søk og velg sted'),
              subtitle: Text('Start, stopp og mål må velges fra søkeresultatet. Da lagres koordinatene og punktet vises på kartet.'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: calculating ? null : _calculate,
              icon: const Icon(Icons.route),
              label: Text(calculating ? 'Beregner…' : 'Beregn ruter'),
            ),
            if (candidates.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionTitle('Velg rute'),
              for (var i = 0; i < candidates.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Card(
                    child: ListTile(
                      onTap: () => setState(() {
                        selectedRouteId = candidates[i].id;
                        previewGeometry = candidates[i].geometry;
                      }),
                      title: Text(candidates[i].name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(_candidateSubtitle(candidates[i])),
                      leading: Icon(
                        _selectedRoute.id == candidates[i].id ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: _selectedRoute.id == candidates[i].id ? GoViaColors.orange : GoViaColors.muted,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _save(_selectedRoute, startNow: false),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Lagre tur'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _save(_selectedRoute, startNow: true),
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text('Start nå'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              const Text('Lagre tur legger den i Turer → Planlagt. Start nå lagrer turen automatisk og åpner navigasjon direkte.', style: TextStyle(color: GoViaColors.muted)),
            ],
          ],
        ),
      );

  RouteCandidate get _selectedRoute {
    if (candidates.isEmpty) throw StateError('Ingen rute er valgt.');
    return candidates.where((candidate) => candidate.id == selectedRouteId).firstOrNull ?? candidates.first;
  }


  Widget _preferenceChip(String label, bool selected, ValueChanged<bool> update) => FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (value) => setState(() {
          update(value);
          candidates = const [];
          previewGeometry = const [];
          selectedRouteId = null;
        }),
      );

  String _candidateSubtitle(RouteCandidate candidate) {
    final km = (candidate.distanceMeters / 1000).round();
    final minutes = (candidate.durationSeconds / 60).round();
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    final duration = hours > 0 ? '${hours}t ${rest}m' : '${rest}m';
    return '$km km · $duration';
  }

  Future<void> _useCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw StateError('Posisjonstjenester er slått av.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw StateError('GoVia har ikke tilgang til posisjonen din.');
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      final placeName = await _reverseGeocode(position.latitude, position.longitude);
      if (!mounted) return;
      final displayName = placeName == null ? 'Her' : 'Her · $placeName';
      final place = PlaceSuggestion(
        label: displayName,
        point: GeoPoint(lat: position.latitude, lon: position.longitude, label: placeName ?? 'Her'),
      );
      start.text = place.label;
      start.selection = TextSelection.collapsed(offset: start.text.length);
      setState(() {
        selectedStart = place;
        candidates = const [];
        previewGeometry = const [];
        selectedRouteId = null;
      });
      FocusScope.of(context).unfocus();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': lat.toStringAsFixed(7),
        'lon': lon.toStringAsFixed(7),
        'zoom': '18',
        'addressdetails': '1',
      });
      final response = await http.get(uri, headers: const {
        'User-Agent': 'GoVia-Mobile/0.1.39 (reverse geocoding)',
        'Accept-Language': 'no,en;q=0.8',
      }).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final address = decoded['address'];
      if (address is Map) {
        final road = (address['road'] ?? address['pedestrian'] ?? address['cycleway'])?.toString().trim();
        final locality = (address['neighbourhood'] ?? address['suburb'] ?? address['quarter'] ?? address['village'] ?? address['town'] ?? address['city'] ?? address['municipality'])?.toString().trim();
        if (road != null && road.isNotEmpty && locality != null && locality.isNotEmpty && road.toLowerCase() != locality.toLowerCase()) return '$road, $locality';
        if (road != null && road.isNotEmpty) return road;
        if (locality != null && locality.isNotEmpty) return locality;
      }
      final name = decoded['name']?.toString().trim();
      if (name != null && name.isNotEmpty && !_looksLikeCoordinates(name)) return name;
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeCoordinates(String value) => RegExp(r'^\s*-?\d{1,3}\.\d+\s*[,; ]\s*-?\d{1,3}\.\d+\s*$').hasMatch(value);

  Future<void> _calculate() async {
    if (selectedStart == null || selectedEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Søk etter og velg både startsted og mål.')));
      return;
    }
    if (via.text.trim().isNotEmpty && selectedVia == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Velg stoppet fra søkeresultatet, eller tøm stoppfeltet.')));
      return;
    }

    setState(() {
      calculating = true;
      candidates = const [];
      previewGeometry = const [];
    });

    try {
      final state = AppScope.of(context);
      final points = <Map<String, dynamic>>[
        {'coord': selectedStart!.coord, 'name': selectedStart!.label},
        if (selectedVia != null) {'coord': selectedVia!.coord, 'name': selectedVia!.label},
        {'coord': selectedEnd!.coord, 'name': selectedEnd!.label},
      ];
      late Map<String, dynamic> routed;
      try {
        routed = await state.api.postJson('/api/v1/map/route', {
          'points': points,
          'mode': routeModeForTransport(transport),
          'profile': profile,
          'preferences': routePreferences.toJson(),
        });
      } catch (_) {
        // Backward-compatible fallback while older GoVia route providers are still deployed.
        routed = await state.api.postJson('/api/v1/map/route', {
          'points': points,
          'mode': routeModeForTransport(transport),
        });
      }
      final data = routed['data'];
      if (data is! Map) throw StateError('Ugyldig rutesvar fra GoVia API.');
      final all = <Map<String, dynamic>>[
        Map<String, dynamic>.from(data),
        ...((data['alternatives'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e))),
      ];
      final parsed = List.generate(all.length, (i) {
        final raw = all[i];
        final geometry = (raw['geometry'] as List? ?? const [])
            .whereType<List>()
            .where((p) => p.length >= 2)
            .map((p) => GeoPoint(lat: (p[1] as num).toDouble(), lon: (p[0] as num).toDouble()))
            .toList(growable: false);
        return RouteCandidate(
          id: 'route-$i-${DateTime.now().microsecondsSinceEpoch}',
          name: i == 0 ? 'Anbefalt' : 'Alternativ $i',
          distanceMeters: (raw['distance'] as num? ?? 0).round(),
          durationSeconds: (raw['duration'] as num? ?? 0).round(),
          geometry: geometry,
          maneuvers: (raw['maneuvers'] as List? ?? const [])
              .whereType<Map>()
              .map((value) => NavigationManeuver.fromJson(Map<String, dynamic>.from(value)))
              .toList(growable: false),
          speedLimitSections: RouteSpeedLimitSection.fromRouteJson(raw, geometry),
          guidanceSource: raw['guidanceSource']?.toString() ?? 'none',
        );
      }).where((candidate) => candidate.geometry.length >= 2).toList(growable: false);
      if (parsed.isEmpty) throw StateError('Rutesvaret mangler kartgeometri.');
      if (!mounted) return;
      final ranked = _rankCandidates(parsed, profile);
      setState(() {
        candidates = ranked;
        selectedRouteId = ranked.first.id;
        previewGeometry = ranked.first.geometry;
      });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ruteberegning feilet: $error')));
    } finally {
      if (mounted) setState(() => calculating = false);
    }
  }

  List<RouteCandidate> _rankCandidates(List<RouteCandidate> input, String selectedProfile) {
    if (input.length < 2) return [...input];
    final values = [...input];
    final minDuration = values.map((c) => c.durationSeconds).reduce((a, b) => a < b ? a : b).toDouble();
    final maxDuration = values.map((c) => c.durationSeconds).reduce((a, b) => a > b ? a : b).toDouble();
    final minDistance = values.map((c) => c.distanceMeters).reduce((a, b) => a < b ? a : b).toDouble();
    final maxDistance = values.map((c) => c.distanceMeters).reduce((a, b) => a > b ? a : b).toDouble();

    double norm(num value, double min, double max) => max <= min ? 0 : ((value.toDouble() - min) / (max - min));
    double score(RouteCandidate candidate) {
      final time = norm(candidate.durationSeconds, minDuration, maxDuration);
      final distance = norm(candidate.distanceMeters, minDistance, maxDistance);
      final curves = _curvatureScore(candidate.geometry);
      return switch (selectedProfile) {
        'shortest' => distance,
        'balanced' => time * .60 + distance * .40,
        'curvy' => time * .35 + distance * .15 - curves * .50,
        'max_curvy' => time * .15 + distance * .05 - curves * .80,
        _ => time,
      };
    }

    values.sort((a, b) => score(a).compareTo(score(b)));
    return List.generate(values.length, (index) {
      final candidate = values[index];
      final name = index == 0 ? _profileLeadLabel(selectedProfile) : 'Alternativ $index';
      return RouteCandidate(
        id: candidate.id,
        name: name,
        distanceMeters: candidate.distanceMeters,
        durationSeconds: candidate.durationSeconds,
        geometry: candidate.geometry,
        maneuvers: candidate.maneuvers,
        speedLimitSections: candidate.speedLimitSections,
        guidanceSource: candidate.guidanceSource,
        official: candidate.official,
      );
    }, growable: false);
  }

  String _profileLeadLabel(String value) {
    for (final option in profilesForTransport(transport)) {
      if (option.id == value) return option.label;
    }
    return 'Anbefalt';
  }


  double _curvatureScore(List<GeoPoint> geometry) {
    if (geometry.length < 3) return 0;
    final step = geometry.length > 80 ? (geometry.length / 80).ceil() : 1;
    var sum = 0.0;
    var count = 0;
    for (var i = step; i + step < geometry.length; i += step) {
      final a = geometry[i - step];
      final b = geometry[i];
      final c = geometry[i + step];
      final h1 = _bearing(a, b);
      final h2 = _bearing(b, c);
      var delta = (h2 - h1).abs();
      if (delta > 180) delta = 360 - delta;
      if (delta >= 8) {
        sum += (delta / 90).clamp(0.0, 1.0).toDouble();
        count++;
      }
    }
    return count == 0 ? 0 : (sum / count).clamp(0.0, 1.0).toDouble();
  }

  double _bearing(GeoPoint a, GeoPoint b) {
    const deg = 3.141592653589793 / 180;
    final lat1 = a.lat * deg;
    final lat2 = b.lat * deg;
    final dLon = (b.lon - a.lon) * deg;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final angle = math.atan2(y, x) / deg;
    return (angle + 360) % 360;
  }

  Future<void> _save(RouteCandidate route, {required bool startNow}) async {
    final now = DateTime.now();
    final stage = Stage(
      id: 'mobile-${now.microsecondsSinceEpoch}',
      day: 0,
      order: 0,
      start: selectedStart!.label,
      end: selectedEnd!.label,
      transport: transport,
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
      routeCandidates: candidates
          .map((candidate) => RouteCandidate(
                id: candidate.id,
                name: candidate.name,
                distanceMeters: candidate.distanceMeters,
                durationSeconds: candidate.durationSeconds,
                geometry: candidate.geometry,
                maneuvers: candidate.maneuvers,
                speedLimitSections: candidate.speedLimitSections,
                guidanceSource: candidate.guidanceSource,
                official: candidate.id == route.id,
              ))
          .toList(growable: false),
      officialRouteId: route.id,
      routeProfile: profile,
      routePreferences: routePreferences,
    );
    final trip = Trip(
      id: 'mobile-trip-${now.microsecondsSinceEpoch}',
      name: '${stage.start} → ${stage.end}',
      startDate: now,
      endDate: now,
      start: stage.start,
      end: stage.end,
      status: TripStatus.planned,
      stages: [stage],
    );
    final state = AppScope.of(context);
    await state.addLocalTrip(trip);
    if (!mounted) return;
    if (startNow) {
      await state.startNavigationStage(stage);
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.navigation, arguments: stage);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turen er lagret under Turer → Planlagt.')));
      Navigator.pushReplacementNamed(context, AppRoutes.trip, arguments: trip);
    }
  }
}

class _PlaceSearchField extends StatefulWidget {
  const _PlaceSearchField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
    required this.onInvalidated,
    this.optional = false,
    this.onUseCurrentLocation,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final PlaceSuggestion? selected;
  final ValueChanged<PlaceSuggestion> onSelected;
  final VoidCallback onInvalidated;
  final bool optional;
  final Future<void> Function()? onUseCurrentLocation;

  @override
  State<_PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<_PlaceSearchField> {
  Timer? _debounce;
  List<PlaceSuggestion> suggestions = const [];
  bool searching = false;
  int generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(String value) {
    if (widget.selected != null && value.trim() != widget.selected!.label) widget.onInvalidated();
    _debounce?.cancel();
    final requestGeneration = ++generation;
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        suggestions = const [];
        searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query, requestGeneration));
  }

  Future<void> _search(String query, int requestGeneration) async {
    if (!mounted) return;
    setState(() => searching = true);
    try {
      final results = await PlaceSearchService.search(query);
      if (!mounted || requestGeneration != generation) return;
      setState(() => suggestions = results);
    } catch (error) {
      if (!mounted || requestGeneration != generation) return;
      setState(() => suggestions = const []);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stedsøk feilet: $error')));
    } finally {
      if (mounted && requestGeneration == generation) setState(() => searching = false);
    }
  }

  void _select(PlaceSuggestion suggestion) {
    _debounce?.cancel();
    generation++;
    widget.controller.text = suggestion.label;
    widget.controller.selection = TextSelection.collapsed(offset: widget.controller.text.length);
    setState(() {
      suggestions = const [];
      searching = false;
    });
    widget.onSelected(suggestion);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          TextField(
            controller: widget.controller,
            onChanged: _changed,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: widget.optional ? '${widget.label} (valgfritt)' : widget.label,
              prefixIcon: widget.onUseCurrentLocation == null
                  ? Icon(widget.icon)
                  : IconButton(
                      tooltip: 'Bruk min posisjon',
                      onPressed: () => widget.onUseCurrentLocation?.call(),
                      icon: Icon(widget.icon),
                    ),
              suffixIcon: searching
                  ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                  : widget.selected != null
                      ? const Icon(Icons.check_circle, color: GoViaColors.green)
                      : null,
            ),
          ),
          if (suggestions.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 6),
              child: Column(
                children: [
                  for (final suggestion in suggestions)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_outlined, color: GoViaColors.cyan),
                      title: Text(suggestion.label),
                      subtitle: Text('${suggestion.point.lat.toStringAsFixed(5)}, ${suggestion.point.lon.toStringAsFixed(5)}'),
                      onTap: () => _select(suggestion),
                    ),
                ],
              ),
            ),
        ],
      );
}
