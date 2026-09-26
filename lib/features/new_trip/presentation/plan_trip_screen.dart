import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/route_profile_picker.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../domain/models.dart';

class PlanTripScreen extends StatefulWidget {
  const PlanTripScreen({super.key});

  @override
  State<PlanTripScreen> createState() => _PlanTripScreenState();
}

class _PlanTripScreenState extends State<PlanTripScreen> {
  final start = TextEditingController();
  final end = TextEditingController();
  final via = TextEditingController();

  _PlaceSuggestion? selectedStart;
  _PlaceSuggestion? selectedVia;
  _PlaceSuggestion? selectedEnd;
  String profile = 'Raskest';
  bool calculating = false;
  List<RouteCandidate> candidates = const [];
  List<GeoPoint> previewGeometry = const [];

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
              onSelected: (place) => setState(() {
                selectedStart = place;
                candidates = const [];
                previewGeometry = const [];
              }),
              onInvalidated: () => setState(() {
                selectedStart = null;
                candidates = const [];
                previewGeometry = const [];
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
              }),
              onInvalidated: () => setState(() {
                selectedVia = null;
                candidates = const [];
                previewGeometry = const [];
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
              }),
              onInvalidated: () => setState(() {
                selectedEnd = null;
                candidates = const [];
                previewGeometry = const [];
              }),
            ),
            const SizedBox(height: 14),
            RouteProfilePicker(
              value: profile,
              enabledProfiles: const {'Raskest'},
              onChanged: (value) => setState(() => profile = value),
            ),
            const SizedBox(height: 10),
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
              const SectionTitle('Rutealternativer'),
              for (var i = 0; i < candidates.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Card(
                    child: ListTile(
                      onTap: () => setState(() => previewGeometry = candidates[i].geometry),
                      title: Text(candidates[i].name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(_candidateSubtitle(candidates[i])),
                      leading: Icon(
                        _previewIndex == i ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: _previewIndex == i ? GoViaColors.orange : GoViaColors.muted,
                      ),
                      trailing: FilledButton(onPressed: () => _save(candidates[i]), child: const Text('Velg')),
                    ),
                  ),
                ),
            ],
          ],
        ),
      );

  int? get _previewIndex {
    if (previewGeometry.isEmpty) return null;
    for (var i = 0; i < candidates.length; i++) {
      if (identical(candidates[i].geometry, previewGeometry) || _sameGeometry(candidates[i].geometry, previewGeometry)) return i;
    }
    return null;
  }

  bool _sameGeometry(List<GeoPoint> a, List<GeoPoint> b) {
    if (a.length != b.length || a.isEmpty) return false;
    return a.first.lat == b.first.lat && a.first.lon == b.first.lon && a.last.lat == b.last.lat && a.last.lon == b.last.lon;
  }

  String _candidateSubtitle(RouteCandidate candidate) {
    final km = (candidate.distanceMeters / 1000).round();
    final minutes = (candidate.durationSeconds / 60).round();
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    final duration = hours > 0 ? '${hours}t ${rest}m' : '${rest}m';
    return '$km km · $duration';
  }

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
      final routed = await state.api.postJson('/api/v1/map/route', {
        'points': points,
        'mode': 'driving',
      });
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
        );
      }).where((candidate) => candidate.geometry.length >= 2).toList(growable: false);
      if (parsed.isEmpty) throw StateError('Rutesvaret mangler kartgeometri.');
      if (!mounted) return;
      setState(() {
        candidates = parsed;
        previewGeometry = parsed.first.geometry;
      });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ruteberegning feilet: $error')));
    } finally {
      if (mounted) setState(() => calculating = false);
    }
  }

  Future<void> _save(RouteCandidate route) async {
    final now = DateTime.now();
    final stage = Stage(
      id: 'mobile-${now.microsecondsSinceEpoch}',
      day: 0,
      order: 0,
      start: selectedStart!.label,
      end: selectedEnd!.label,
      transport: StageTransport.motorcycle,
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
      routeCandidates: [route.copyWith(official: true)],
      officialRouteId: route.id,
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
    await AppScope.of(context).addLocalTrip(trip);
    if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.trip, arguments: trip);
  }
}

class _PlaceSuggestion {
  const _PlaceSuggestion({required this.label, required this.point});

  final String label;
  final GeoPoint point;
  List<double> get coord => [point.lon, point.lat];
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
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final _PlaceSuggestion? selected;
  final ValueChanged<_PlaceSuggestion> onSelected;
  final VoidCallback onInvalidated;
  final bool optional;

  @override
  State<_PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<_PlaceSearchField> {
  Timer? _debounce;
  List<_PlaceSuggestion> suggestions = const [];
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
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        suggestions = const [];
        searching = false;
      });
      return;
    }
    final requestGeneration = ++generation;
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query, requestGeneration));
  }

  Future<void> _search(String query, int requestGeneration) async {
    if (!mounted) return;
    setState(() => searching = true);
    try {
      final response = await AppScope.of(context).api.postJson('/api/v1/map/geocode', {'query': query});
      if (!mounted || requestGeneration != generation) return;
      setState(() => suggestions = _parseSuggestions(response));
    } on ApiException catch (error) {
      if (!mounted || requestGeneration != generation) return;
      setState(() => suggestions = const []);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stedsøk feilet: ${error.message}')));
    } catch (error) {
      if (!mounted || requestGeneration != generation) return;
      setState(() => suggestions = const []);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stedsøk feilet: $error')));
    } finally {
      if (mounted && requestGeneration == generation) setState(() => searching = false);
    }
  }

  List<_PlaceSuggestion> _parseSuggestions(Map<String, dynamic> response) {
    final payload = response['data'];
    if (payload is! Map) return const [];
    final features = payload['features'];
    if (features is! List) return const [];
    final result = <_PlaceSuggestion>[];
    final seen = <String>{};
    for (final feature in features.whereType<Map>()) {
      final geometry = feature['geometry'];
      if (geometry is! Map) continue;
      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2 || coords[0] is! num || coords[1] is! num) continue;
      final properties = feature['properties'] is Map ? feature['properties'] as Map : const {};
      final parts = <String>[
        properties['name']?.toString() ?? '',
        properties['city']?.toString() ?? properties['town']?.toString() ?? properties['village']?.toString() ?? '',
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
      result.add(_PlaceSuggestion(point: GeoPoint(lat: (coords[1] as num).toDouble(), lon: (coords[0] as num).toDouble()), label: label));
      if (result.length >= 6) break;
    }
    return result;
  }

  void _select(_PlaceSuggestion suggestion) {
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
              prefixIcon: Icon(widget.icon),
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
