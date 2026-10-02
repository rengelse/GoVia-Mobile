import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/app_scope.dart';
import '../../../app/app_routes.dart';
import '../../new_trip/data/place_search_service.dart';

class DestinationSearchScreen extends StatefulWidget {
  const DestinationSearchScreen({super.key});
  @override
  State<DestinationSearchScreen> createState() => _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _generation = 0;
  String _query = '';
  bool _loading = false;
  String? _error;
  List<PlaceSuggestion> _places = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      _query = value.trim().toLowerCase();
      _places = const [];
      _error = null;
      _loading = _query.length >= 2;
    });
    if (!_loading) return;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final places = await PlaceSearchService.search(value.trim());
        if (!mounted || generation != _generation) return;
        setState(() { _places = places; _loading = false; });
      } catch (_) {
        if (!mounted || generation != _generation) return;
        setState(() { _loading = false; _error = 'Stedsøk er utilgjengelig. Prøv igjen.'; });
      }
    });
  }

  bool _matches(String value) => _query.length >= 2 && value.toLowerCase().contains(_query);

  void _plan(PlaceSuggestion place) {
    Navigator.pushReplacementNamed(context, AppRoutes.planTrip, arguments: place);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final trips = state.trips.where((trip) => _matches('${trip.name} ${trip.start} ${trip.end}')).take(8).toList();
    final routes = state.publishedRoutes.where((route) => route.status == 'published' && route.visibility == 'public' && _matches('${route.title} ${route.tags.join(' ')}')).take(8).toList();
    final pois = state.pois.where((poi) => _matches(poi.name)).take(6).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Hvor vil du reise?')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _changed,
            decoration: const InputDecoration(hintText: 'Søk etter destinasjon, sted eller adresse', prefixIcon: Icon(Icons.search)),
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(child: ListView(children: [
          if (_query.length < 2) const ListTile(title: Text('Skriv minst to tegn for å søke.')),
          if (_error != null) ListTile(title: Text(_error!)),
          if (_places.isNotEmpty) const ListTile(title: Text('Steder og adresser')),
          for (final place in _places)
            ListTile(leading: const Icon(Icons.location_on_outlined), title: Text(place.label), subtitle: const Text('Bruk som destinasjon'), onTap: () => _plan(place)),
          if (pois.isNotEmpty) const ListTile(title: Text('POI fra turen')),
          for (final poi in pois)
            ListTile(leading: const Icon(Icons.place_outlined), title: Text(poi.name), subtitle: const Text('Finn sted og velg mål'), onTap: () { _controller.text = poi.name; _changed(poi.name); }),
          if (trips.isNotEmpty) const ListTile(title: Text('Egne turer')),
          for (final trip in trips)
            ListTile(leading: const Icon(Icons.route_outlined), title: Text(trip.name), subtitle: Text('${trip.start} → ${trip.end}'), onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.trip, arguments: trip)),
          if (routes.isNotEmpty) const ListTile(title: Text('Publiserte turer')),
          for (final route in routes)
            ListTile(leading: const Icon(Icons.public), title: Text(route.title), onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.publishedRoute, arguments: route)),
          if (_query.length >= 2 && !_loading && _error == null && _places.isEmpty && pois.isEmpty && trips.isEmpty && routes.isEmpty)
            const ListTile(title: Text('Ingen treff. Prøv et annet navn eller en adresse.')),
        ])),
      ]),
    );
  }
}
