import 'package:flutter/material.dart';
import '../../../app/app_scope.dart';
import '../../../app/app_state.dart';
import '../../../app/app_routes.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../domain/models.dart';

class PlanTripScreen extends StatefulWidget { const PlanTripScreen({super.key}); @override State<PlanTripScreen> createState() => _PlanTripScreenState(); }
class _PlanTripScreenState extends State<PlanTripScreen> {
  final start = TextEditingController(); final end = TextEditingController(); final via = TextEditingController(); String profile = 'Raskest'; bool calculating = false; List<RouteCandidate> candidates = const [];
  @override void dispose(){start.dispose();end.dispose();via.dispose();super.dispose();}
  @override Widget build(BuildContext context) => GoViaScreen(title: 'Planlegg tur', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const RouteMapCard(height: 230, label: 'Ny rute'), const SizedBox(height: 16),
    TextField(controller: start, decoration: const InputDecoration(labelText: 'Startsted', prefixIcon: Icon(Icons.trip_origin))), const SizedBox(height: 10),
    TextField(controller: via, decoration: const InputDecoration(labelText: 'Stopp / via (valgfritt)', prefixIcon: Icon(Icons.add_location_alt_outlined))), const SizedBox(height: 10),
    TextField(controller: end, decoration: const InputDecoration(labelText: 'Mål', prefixIcon: Icon(Icons.flag_outlined))), const SizedBox(height: 14),
    DropdownButtonFormField<String>(initialValue: profile, decoration: const InputDecoration(labelText: 'Ruteprofil'), items: const [DropdownMenuItem(value:'Raskest',child:Text('Raskest')),DropdownMenuItem(value:'Balansert',enabled:false,child:Text('Balansert · krever ny serverkontrakt')),DropdownMenuItem(value:'Svingete',enabled:false,child:Text('Svingete · krever ny serverkontrakt')),DropdownMenuItem(value:'Maks svingete',enabled:false,child:Text('Maks svingete · krever ny serverkontrakt'))], onChanged:(v)=>setState(()=>profile=v??profile)),
    const SizedBox(height: 10),
    const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.info_outline), title: Text('Avanserte rutevalg'), subtitle: Text('Unngå motorvei og eksplisitt fergevalg aktiveres når GoVia API har en låst ruteprofil-kontrakt.')),
    const SizedBox(height: 10), FilledButton.icon(onPressed: calculating ? null : _calculate, icon: const Icon(Icons.route), label: Text(calculating ? 'Beregner…' : 'Beregn ruter')),
    if (candidates.isNotEmpty) ...[const SizedBox(height: 20), const SectionTitle('Rutealternativer'), for(final c in candidates) Padding(padding: const EdgeInsets.only(bottom: 9), child: Card(child: ListTile(title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${(c.distanceMeters/1000).round()} km · ${c.durationSeconds~/3600} t'), trailing: FilledButton(onPressed:()=>_save(c), child: const Text('Velg')))))],
  ]));
  Future<void> _calculate() async {
    if (start.text.trim().isEmpty || end.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Velg start og mål.')));
      return;
    }
    setState(() { calculating = true; candidates = const []; });
    try {
      final state = AppScope.of(context);
      final startGeo = await state.api.postJson('/api/v1/map/geocode', {'query': start.text.trim()});
      final endGeo = await state.api.postJson('/api/v1/map/geocode', {'query': end.text.trim()});
      final a = _firstCoordinate(startGeo);
      final b = _firstCoordinate(endGeo);
      if (a == null || b == null) throw StateError('Fant ikke start eller mål i stedsøket.');
      final points = <Map<String, dynamic>>[
        {'coord': a, 'name': start.text.trim()},
        if (via.text.trim().isNotEmpty) ...await _viaPoint(state),
        {'coord': b, 'name': end.text.trim()},
      ];
      final routed = await state.api.postJson('/api/v1/map/route', {
        'points': points,
        'mode': 'driving',
      });
      final data = routed['data'];
      if (data is! Map) throw StateError('Ugyldig rutesvar fra GoVia API.');
      final all = <Map<String, dynamic>>[Map<String, dynamic>.from(data), ...((data['alternatives'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)))];
      setState(() {
        candidates = List.generate(all.length, (i) {
          final raw = all[i];
          final geometry = (raw['geometry'] as List? ?? const []).whereType<List>().where((p) => p.length >= 2).map((p) => GeoPoint(lat: (p[1] as num).toDouble(), lon: (p[0] as num).toDouble())).toList();
          return RouteCandidate(id: 'route-$i-${DateTime.now().microsecondsSinceEpoch}', name: i == 0 ? 'Anbefalt' : 'Alternativ $i', distanceMeters: (raw['distance'] as num? ?? 0).round(), durationSeconds: (raw['duration'] as num? ?? 0).round(), geometry: geometry);
        });
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ruteberegning feilet: $e')));
    } finally {
      if (mounted) setState(() => calculating = false);
    }
  }
  List<double>? _firstCoordinate(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) return null;
    final features = data['features'];
    if (features is! List || features.isEmpty) return null;
    final first = features.first;
    if (first is! Map) return null;
    final geometry = first['geometry'];
    if (geometry is! Map) return null;
    final coords = geometry['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    return [(coords[0] as num).toDouble(), (coords[1] as num).toDouble()];
  }
  Future<List<Map<String, dynamic>>> _viaPoint(AppState state) async {
    final result = await state.api.postJson('/api/v1/map/geocode', {'query': via.text.trim()});
    final coord = _firstCoordinate(result);
    return coord == null ? const [] : [{'coord': coord, 'name': via.text.trim()}];
  }
  Future<void> _save(RouteCandidate route) async { final now=DateTime.now(); final stage=Stage(id:'mobile-${now.microsecondsSinceEpoch}',day:0,order:0,start:start.text.trim(),end:end.text.trim(),transport:StageTransport.motorcycle,distanceMeters:route.distanceMeters,durationSeconds:route.durationSeconds,routeCandidates:[route.copyWith(official:true)],officialRouteId:route.id); final trip=Trip(id:'mobile-trip-${now.microsecondsSinceEpoch}',name:'${stage.start} → ${stage.end}',startDate:now,endDate:now,start:stage.start,end:stage.end,status:TripStatus.planned,stages:[stage]); await AppScope.of(context).addLocalTrip(trip); if(mounted) Navigator.pushReplacementNamed(context,AppRoutes.trip,arguments:trip); }
}
