import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';

import 'destination_search_screen.dart';
import 'map_settings_sheet.dart';
import 'map_overlay_renderer.dart';
import '../domain/map_home_preferences.dart';
import '../domain/discovery_categories.dart';
import '../data/map_place_repository.dart';
import '../../new_trip/domain/plan_trip_request.dart';
import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../app/app_state.dart';
import '../../../core/theme/govia_theme.dart';
import 'map_home_widgets.dart';
import '../../../domain/models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _requestedRoutes = false;
  bool _darkMap = true;
  bool _mapStyleLoaded = false;
  bool _fitAfterDraw = true;
  MapHomePreferences _preferences = const MapHomePreferences();
  StageTransport? _transportOverride;
  StageTransport? _observedTransport;
  String _categoryId = 'all';
  List<MapPlace> _places = const [];
  bool _placesLoading = false;
  String? _placesError;
  int _placesGeneration = 0;
  MapPlaceRepository? _placeRepository;
  final _overlays = MapOverlayRenderer();
  Future<void> _savePreferences = Future<void>.value();
  GeoPoint? _lastPlacePoint;
  String? _lastPlaceCategory;
  StageTransport? _lastPlaceTransport;
  DateTime? _lastPlaceFetch;
  Timer? _weatherDebounce;
  CameraPosition? _camera;
  String _weatherLocation = 'Kartområdet';
  bool _locating = false;

  String get _style => _preferences.style(dark: _darkMap);
  StageTransport get _transport => discoveryTransport(_transportOverride ?? AppScope.of(context).profile?.preferredTransport ?? StageTransport.car);
  DiscoveryCategory get _category => discoveryCategories(_transport).where((item) => item.id == _categoryId).firstOrNull ?? discoveryCategories(_transport).first;

  void _changePreferences(MapHomePreferences value) {
    if (!mounted) return;
    final styleChanged = _preferences.mapType != value.mapType;
    setState(() {
      _preferences = value;
      if (styleChanged) {
        _fitAfterDraw = false;
        _mapStyleLoaded = false;
        _mapController = null;
        _overlays.detach();
      }
      if (!value.places) { _placesGeneration++; _places = const []; _placesLoading = false; _placesError = null; }
    });
    final store = AppScope.of(context).store;
    _savePreferences = _savePreferences.then((_) async {
      try { await store.writeJson('home_map_preferences', value.toJson()); }
      catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kartvalgene kunne ikke lagres.'))); }
    });
    if (value.places) _loadPlaces(force: true);
  }

  Future<void> _selectTransport() async {
    final chosen = await showModalBottomSheet<String>(context: context, builder: (context) => SafeArea(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [const ListTile(title: Text('Utforsk med')),
        for (final mode in const [StageTransport.motorcycle, StageTransport.car, StageTransport.walking, StageTransport.cycling, StageTransport.train])
          ListTile(leading: Icon(_transportIcon(mode)), title: Text(transportLabel(mode)),
            trailing: mode == _transport ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(context, mode.name)),
        ListTile(title: const Text('Bruk foretrukket transport fra Profil'),
          onTap: () => Navigator.pop(context, 'profile')),
      ],
    )));
    if (!mounted || chosen == null) return;
    setState(() { _transportOverride = chosen == 'profile' ? null : StageTransport.values.firstWhere((mode) => mode.name == chosen); _observedTransport = _transport; _categoryId = 'all'; _placesGeneration++; _places = const []; _placesLoading = false; _placesError = null; });
  }

  Future<void> _loadPlaces({bool force = false}) async {
    if (!mounted) return;
    final category = _category;
    if (!_preferences.places || category.poiCategory == null) return;
    final transport = _transport;
    final first = _tripGeometry(AppScope.of(context).activeTrip).firstOrNull;
    final target = _camera?.target ?? (first == null ? _bergen : LatLng(first.lat, first.lon));
    final point = GeoPoint(lat: target.latitude, lon: target.longitude);
    final sameArea = _lastPlacePoint != null && (point.lat - _lastPlacePoint!.lat).abs() < .008 && (point.lon - _lastPlacePoint!.lon).abs() < .012;
    if (!force && sameArea && category.id == _lastPlaceCategory && transport == _lastPlaceTransport &&
        (_placesLoading || (_lastPlaceFetch != null && DateTime.now().difference(_lastPlaceFetch!) < const Duration(minutes: 15)))) return;
    final generation = ++_placesGeneration;
    _lastPlacePoint = point; _lastPlaceCategory = category.id; _lastPlaceTransport = transport;
    setState(() { _placesLoading = true; _placesError = null; _places = const []; });
    try {
      _placeRepository ??= MapPlaceRepository(AppScope.of(context).api);
      final result = await _placeRepository!.around(point, category, transport);
      if (!mounted || generation != _placesGeneration) return;
      setState(() { _places = result; _lastPlaceFetch = DateTime.now(); });
    } catch (_) {
      if (!mounted || generation != _placesGeneration) return;
      setState(() { _placesError = 'Kunne ikke hente steder. Trykk for å prøve igjen.'; _lastPlaceFetch = null; });
    } finally {
      if (mounted && generation == _placesGeneration) setState(() => _placesLoading = false);
    }
  }

  void _chooseCategory(DiscoveryCategory category) {
    setState(() { _categoryId = category.id; _placesGeneration++; _places = const []; _placesLoading = false; _placesError = null; _lastPlaceFetch = null; });
    _loadPlaces(force: true);
  }

  static IconData _transportIcon(StageTransport mode) => switch (mode) {
    StageTransport.motorcycle => Icons.two_wheeler, StageTransport.car => Icons.directions_car,
    StageTransport.walking => Icons.directions_walk, StageTransport.cycling => Icons.pedal_bike,
    StageTransport.train => Icons.train, StageTransport.ferry => Icons.directions_car,
  };

  List<MapRouteOverlay> _routeOverlays(AppState state, List<PublishedRoute> routes) {
    final overlays = <MapRouteOverlay>[];
    if (_preferences.completedTrips) {
      var completedCount = 0;
      completed: for (final trip in state.trips.where((t) => t.status == TripStatus.completed)) {
        for (final stage in trip.stages.where((stage) => stage.transport == _transport)) {
          final route = stage.routeCandidates.where((r) => r.id == stage.officialRouteId).firstOrNull ?? stage.routeCandidates.where((r) => r.official).firstOrNull ?? stage.routeCandidates.firstOrNull;
          if (route != null && route.geometry.length > 1) {
            overlays.add(MapRouteOverlay(id: 'completed:${trip.id}:${stage.id}', geometry: route.geometry, color: '#A78BFA', target: trip));
            if (++completedCount >= 29) break completed;
          }
        }
      }
    }
    for (final route in routes.take(50)) {
      final favorite = route.saved && _preferences.favorites;
      if (!_preferences.publishedRoutes && !favorite) continue;
      overlays.add(MapRouteOverlay(id: 'published:${route.id}', geometry: route.geometry, color: favorite ? '#42D392' : '#10A9FF', target: route));
    }
    if (_preferences.activeTrip && state.activeTrip != null) overlays.add(MapRouteOverlay(
      id: 'active:${state.activeTrip!.id}', geometry: _tripGeometry(state.activeTrip), color: '#FF7A21', target: state.activeTrip));
    return overlays;
  }

  void _updateOverlays() {
    if (!mounted || !_mapStyleLoaded) return;
    final state = AppScope.of(context);
    final routes = filterDiscoveryRoutes(state.publishedRoutes, _transport, _category);
    _overlays.render(_routeOverlays(state, routes), _preferences.places ? _places : const []);
  }

  void _openMapTarget(Circle circle) {
    if (!mounted) return;
    final target = _overlays.targets[circle.id];
    if (target is PublishedRoute) Navigator.pushNamed(context, AppRoutes.publishedRoute, arguments: target);
    if (target is Trip) Navigator.pushNamed(context, AppRoutes.trip, arguments: target);
    if (target is MapPlace) _showPlace(target);
  }

  void _showPlaces() {
    showModalBottomSheet<void>(context: context, isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
      builder: (context) => SafeArea(child: _places.isEmpty
        ? Padding(padding: const EdgeInsets.all(24), child: Text('Ingen registrerte ${_category.label.toLowerCase()} i kartområdet.'))
        : ListView(shrinkWrap: true, children: [
          ListTile(title: Text(_category.label)),
          for (final place in _places) ListTile(title: Text(place.name), subtitle: Text(place.category),
            onTap: () { Navigator.pop(context); _showPlace(place); }),
        ])));
  }

  void _showPlace(MapPlace place) {
    showModalBottomSheet<void>(context: context, builder: (context) => SafeArea(child: Padding(
      padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(place.name, style: Theme.of(context).textTheme.titleLarge), Text(place.category), const SizedBox(height: 14),
        FilledButton.icon(onPressed: () { Navigator.pop(context); Navigator.pushNamed(this.context, AppRoutes.planTrip, arguments: PlanTripRequest(destinationLabel: place.name, destination: place.point, transport: _transport)); },
          icon: const Icon(Icons.navigation_outlined), label: const Text('Bruk som destinasjon')),
      ]))));
  }

  @override
  void dispose() {
    _weatherDebounce?.cancel();
    _placesGeneration++;
    _overlays.detach();
    super.dispose();
  }

  void _refreshMapWeather({bool force = false}) {
    final first = _tripGeometry(AppScope.of(context).activeTrip).firstOrNull;
    final target = _camera?.target ?? (first == null ? _bergen : LatLng(first.lat, first.lon));
    AppScope.of(context).refreshMapWeather(GeoPoint(lat: target.latitude, lon: target.longitude), label: _weatherLocation, force: force);
  }

  void _cameraIdle() {
    _weatherDebounce?.cancel();
    _weatherDebounce = Timer(const Duration(milliseconds: 700), () {
      if (mounted) { _refreshMapWeather(); _loadPlaces(); }
    });
  }

  Future<void> _showWeather() async {
    _refreshMapWeather();
    await showModalBottomSheet<void>(context: context, builder: (context) {
      final state = AppScope.of(context);
      return AnimatedBuilder(animation: state, builder: (context, _) {
        final forecast = state.mapWeather;
        final weather = forecast?.points.firstOrNull;
        return SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vær · ${state.mapWeatherLocation}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (state.mapWeatherLoading) const LinearProgressIndicator()
            else if (weather != null) ...[
              Text('I dag · ${MapHomeTopBar.temperatureLabel(weather)}', style: Theme.of(context).textTheme.headlineSmall),
              Text('Vind opptil ${weather.wind.toStringAsFixed(1)} m/s · ${weather.precipitation.toStringAsFixed(1)} mm nedbør'),
              Text('Dagsprognose · ${forecast!.providerLabel}', style: Theme.of(context).textTheme.bodySmall),
            ] else Text(state.mapWeatherMessage ?? 'Ingen værdata tilgjengelig.'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              TextButton.icon(onPressed: () => _refreshMapWeather(force: true), icon: const Icon(Icons.refresh), label: const Text('Prøv igjen')),
              if (state.activeTrip != null) TextButton(onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(this.context, AppRoutes.weather);
              }, child: const Text('Vær langs turen')),
            ]),
          ],
        )));
      });
    });
  }

  Future<void> _showMapLayers() => showModalBottomSheet<void>(
    context: context, isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
    builder: (_) => MapSettingsSheet(preferences: _preferences, onChanged: _changePreferences),
  );
  MapLibreMapController? _mapController;

  static const _bergen = LatLng(60.39299, 5.32415);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (_darkMap != dark) {
      _darkMap = dark;
      _fitAfterDraw = _camera == null;
      _mapStyleLoaded = false;
      _mapController = null;
      _overlays.detach();
    }
    final transport = _transport;
    if (_observedTransport != transport) {
      _observedTransport = transport;
      _categoryId = 'all';
      _placesGeneration++;
      _places = const [];
      _placesLoading = false;
      _placesError = null;
    }
    if (_requestedRoutes) return;
    _requestedRoutes = true;
    _preferences = MapHomePreferences.fromJson(AppScope.of(context).store.readJson('home_map_preferences'));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = AppScope.of(context);
      _refreshMapWeather();
      try {
        await state.refreshPublishedRoutes();
      } catch (_) {
        // Existing cached/public route state remains available when offline.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final trip = state.activeTrip;
    final routeGeometry = _tripGeometry(trip);
    final filteredRoutes = filterDiscoveryRoutes(state.publishedRoutes, _transport, _category);
    final discoveryRoutes = _rankedRoutes(filteredRoutes);
    if (_mapStyleLoaded) WidgetsBinding.instance.addPostFrameCallback((_) => _updateOverlays());

    return Stack(
      fit: StackFit.expand,
      children: [
        MapLibreMap(
          key: ValueKey(_style),
          styleString: _style,
          trackCameraPosition: true,
          onCameraMove: (camera) { _camera = camera; _weatherLocation = 'Kartområdet'; },
          onCameraIdle: _cameraIdle,
          initialCameraPosition: _camera ?? CameraPosition(
            target: routeGeometry.isNotEmpty ? LatLng(routeGeometry.first.lat, routeGeometry.first.lon) : _bergen,
            zoom: routeGeometry.length > 1 ? 7.5 : 10,
          ),
          attributionButtonPosition: AttributionButtonPosition.bottomLeft,
          attributionButtonMargins: math.Point<double>(12, MediaQuery.paddingOf(context).bottom + 8),
          compassEnabled: false,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          onMapCreated: (controller) {
            _mapController = controller;
            controller.onCircleTapped.add(_openMapTarget);
          },
          onStyleLoadedCallback: () {
            _mapStyleLoaded = true;
            final controller = _mapController;
            if (controller == null) return;
            _overlays.attach(controller);
            _updateOverlays();
            if (_fitAfterDraw && routeGeometry.length > 1) {
              _fitAfterDraw = false;
              _fitRoute(routeGeometry, controller);
            }
          },
        ),
        const MapHomeScrim(),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                child: MapHomeTopBar(
                  state: state,
                  onProfile: () => state.setShellIndex(3),
                  onWeather: _showWeather,
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: MapHomeSearchBar(
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DestinationSearchScreen(transport: _transport))),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    MapDiscoveryChip(icon: _transportIcon(_transport), label: transportLabel(_transport), selected: _transportOverride != null, onTap: _selectTransport),
                    for (final category in discoveryCategories(_transport))
                      MapDiscoveryChip(icon: category.poiCategory != null ? Icons.place_outlined : Icons.route_outlined,
                        label: category.label, selected: category.id == _category.id, onTap: () => _chooseCategory(category)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TripDiscoveryCarousel(routes: discoveryRoutes),
              if (discoveryRoutes.isEmpty && state.publishedRoutes.isNotEmpty && _category.id != 'all')
                Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Text('Ingen publiserte turer i denne kategorien.', style: Theme.of(context).textTheme.bodySmall)),
              if (_preferences.places && _category.poiCategory != null)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6), child: Material(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: .94), borderRadius: BorderRadius.circular(12),
                  child: InkWell(onTap: () => _placesError != null ? _loadPlaces(force: true) : _showPlaces(),
                    child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
                      if (_placesLoading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      else const Icon(Icons.place_outlined, size: 18),
                      const SizedBox(width: 8), Expanded(child: Text(_placesLoading ? 'Henter ${_category.label.toLowerCase()} …' :
                        _placesError ?? (_places.isEmpty ? 'Ingen registrerte treff i kartområdet' : '${_places.length} steder · ${_category.label}'),
                        style: const TextStyle(fontSize: 12))), const Icon(Icons.chevron_right, size: 18),
                    ]))),
                )),
              const Spacer(),
            ],
          ),
        ),
        Positioned(
          right: 18,
          bottom: MediaQuery.paddingOf(context).bottom + 84,
          child: Column(
            children: [
              MapHomeActionButton(
                icon: Icons.layers_outlined,
                tooltip: 'Kartinnstillinger',
                onTap: _showMapLayers,
              ),
              const SizedBox(height: 10),
              MapHomeActionButton(icon: Icons.my_location_rounded, tooltip: _locating ? 'Henter posisjon' : 'Sentrer kart', onTap: () => _recenter(routeGeometry)),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
          child: Center(
            child: FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.newTrip, arguments: _transport),
              style: FilledButton.styleFrom(
                backgroundColor: GoViaColors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(220, 54),
                padding: const EdgeInsets.symmetric(horizontal: 30),
                shape: const StadiumBorder(),
                elevation: 10,
                shadowColor: Colors.black54,
              ),
              icon: const Icon(Icons.navigation_rounded, size: 26),
              label: const Text('Planlegg tur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ],
    );
  }

  List<PublishedRoute> _rankedRoutes(List<PublishedRoute> source) {
    final routes = source.where((route) => route.status == 'published' && route.visibility == 'public').toList(growable: false);
    final ranked = [...routes]
      ..sort((a, b) {
        final aPhoto = a.photoUrls.isNotEmpty ? 1 : 0;
        final bPhoto = b.photoUrls.isNotEmpty ? 1 : 0;
        if (aPhoto != bPhoto) return bPhoto.compareTo(aPhoto);
        final aRating = a.rating?.overall ?? 0;
        final bRating = b.rating?.overall ?? 0;
        if (aRating != bRating) return bRating.compareTo(aRating);
        if (a.ratingCount != b.ratingCount) return b.ratingCount.compareTo(a.ratingCount);
        return a.title.compareTo(b.title);
      });
    return ranked.take(10).toList(growable: false);
  }

  List<GeoPoint> _tripGeometry(Trip? trip) {
    if (trip == null) return const [];
    final result = <GeoPoint>[];
    for (final stage in trip.stages) {
      RouteCandidate? route;
      if (stage.officialRouteId != null) {
        for (final candidate in stage.routeCandidates) {
          if (candidate.id == stage.officialRouteId) {
            route = candidate;
            break;
          }
        }
      }
      route ??= stage.routeCandidates.where((candidate) => candidate.official).firstOrNull;
      route ??= stage.routeCandidates.firstOrNull;
      if (route == null || route.geometry.isEmpty) continue;
      if (result.isNotEmpty && result.last == route.geometry.first) {
        result.addAll(route.geometry.skip(1));
      } else {
        result.addAll(route.geometry);
      }
    }
    return result;
  }

  Future<void> _recenter(List<GeoPoint> route) async {
    final controller = _mapController;
    if (controller == null) return;
    if (route.length > 1) {
      await _fitRoute(route, controller);
    } else {
      if (_locating) return;
      setState(() => _locating = true);
      try {
        if (!await Geolocator.isLocationServiceEnabled()) throw StateError('Slå på posisjonstjenester for å sentrere på deg.');
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw StateError('Posisjonstilgang mangler.');
        final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium)).timeout(const Duration(seconds: 12));
        if (!mounted || controller != _mapController) return;
        final target = LatLng(position.latitude, position.longitude);
        await controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 13)));
        if (!mounted) return;
        _weatherLocation = 'Min posisjon';
        _weatherDebounce?.cancel();
        AppScope.of(context).refreshMapWeather(GeoPoint(lat: position.latitude, lon: position.longitude), label: 'Min posisjon');
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      } finally {
        if (mounted) setState(() => _locating = false);
      }
    }
  }

  Future<void> _fitRoute(List<GeoPoint> route, MapLibreMapController controller) async {
    if (route.length < 2) return;
    final minLat = route.map((point) => point.lat).reduce(math.min);
    final maxLat = route.map((point) => point.lat).reduce(math.max);
    final minLon = route.map((point) => point.lon).reduce(math.min);
    final maxLon = route.map((point) => point.lon).reduce(math.max);
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLon), northeast: LatLng(maxLat, maxLon)),
        left: 44,
        top: 350,
        right: 44,
        bottom: 180,
      ),
    );
  }
}

