import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../app/app_state.dart';
import '../../../core/location/place_search_service.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../domain/models.dart';
import '../../new_trip/presentation/plan_trip_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _requestedRoutes = false;
  bool _mapStyleLoaded = false;
  String? _drawnRouteKey;
  MapLibreMapController? _mapController;

  static const _bergen = LatLng(60.39299, 5.32415);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedRoutes) return;
    _requestedRoutes = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = AppScope.of(context);
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
    final discoveryRoutes = _rankedRoutes(state.publishedRoutes);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        MapLibreMap(
          key: ValueKey('home-map-${dark ? 'dark' : 'light'}'),
          styleString: dark
              ? 'https://tiles.openfreemap.org/styles/dark'
              : 'https://tiles.openfreemap.org/styles/liberty',
          initialCameraPosition: CameraPosition(
            target: routeGeometry.isNotEmpty ? LatLng(routeGeometry.first.lat, routeGeometry.first.lon) : _bergen,
            zoom: routeGeometry.length > 1 ? 7.5 : 10,
          ),
          compassEnabled: false,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          onMapCreated: (controller) {
            _mapController = controller;
            _drawnRouteKey = null;
            _drawRoute(routeGeometry, dark: dark);
          },
          onStyleLoadedCallback: () {
            _mapStyleLoaded = true;
            _drawnRouteKey = null;
            _drawRoute(routeGeometry, dark: dark);
          },
        ),
        _MapScrim(dark: dark),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                child: _TopBar(
                  state: state,
                  onProfile: () => state.setShellIndex(3),
                  onWeather: () => Navigator.pushNamed(context, AppRoutes.weather),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SearchBar(
                  onTap: _openDestinationSearch,
                  onFilter: () => Navigator.pushNamed(context, AppRoutes.discover),
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 40,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _DiscoveryChip(icon: Icons.landscape_outlined, label: 'Naturopplevelser', onTap: () => Navigator.pushNamed(context, AppRoutes.discover)),
                    _DiscoveryChip(icon: Icons.alt_route_rounded, label: 'Spennende ruter', onTap: () => Navigator.pushNamed(context, AppRoutes.discover)),
                    _DiscoveryChip(icon: Icons.place_outlined, label: 'Severdigheter', onTap: () => Navigator.pushNamed(context, AppRoutes.discover)),
                    _DiscoveryChip(icon: Icons.restaurant_outlined, label: 'Mat', onTap: () => Navigator.pushNamed(context, AppRoutes.poi)),
                  ],
                ),
              ),
              if (discoveryRoutes.isNotEmpty) ...[
                const SizedBox(height: 10),
                _TripDiscoveryCarousel(routes: discoveryRoutes),
              ],
              const Spacer(),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 202,
          child: Column(
            children: [
              _MapActionButton(
                icon: Icons.layers_outlined,
                tooltip: 'Kartstil',
                onTap: _showMapStyleInfo,
              ),
              const SizedBox(height: 9),
              _MapActionButton(icon: Icons.my_location_rounded, tooltip: 'Sentrer kart', onTap: () => _recenter(routeGeometry)),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 118,
          child: Center(
            child: FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.newTrip),
              style: FilledButton.styleFrom(
                backgroundColor: GoViaColors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(232, 56),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: const StadiumBorder(),
                elevation: 8,
                shadowColor: Colors.black45,
              ),
              icon: const Icon(Icons.navigation_rounded, size: 24),
              label: const Text('Planlegg tur', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openDestinationSearch() async {
    final result = await showModalBottomSheet<PlaceSearchResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _DestinationSearchSheet(),
    );
    if (!mounted || result == null) return;
    await Navigator.pushNamed(
      context,
      AppRoutes.planTrip,
      arguments: PlanTripArgs(destinationLabel: result.label, destination: result.point),
    );
  }

  Future<void> _showMapStyleInfo() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListTile(
            leading: const Icon(Icons.layers_outlined, color: GoViaColors.orange),
            title: const Text('Kartstil følger app-tema', style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: const Text('Lyst tema bruker lyst kart. Mørkt tema bruker mørkt kart. Endre tema under Profil → App.'),
            trailing: const Icon(Icons.check_circle_rounded, color: GoViaColors.orange),
            onTap: () => Navigator.pop(sheetContext),
          ),
        ),
      );

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

  Future<void> _drawRoute(List<GeoPoint> route, {required bool dark}) async {
    final controller = _mapController;
    if (controller == null || !_mapStyleLoaded || route.length < 2) return;
    final key = '${route.length}:${route.first.lat}:${route.first.lon}:${route.last.lat}:${route.last.lon}:$dark';
    if (_drawnRouteKey == key) return;
    _drawnRouteKey = key;
    final geometry = route.map((point) => LatLng(point.lat, point.lon)).toList(growable: false);
    try {
      await controller.addLine(
        LineOptions(
          geometry: geometry,
          lineColor: '#FF7A21',
          lineWidth: 5.5,
          lineOpacity: .95,
        ),
      );
      await _fitRoute(route, controller);
    } catch (_) {
      _drawnRouteKey = null;
    }
  }

  Future<void> _recenter(List<GeoPoint> route) async {
    final controller = _mapController;
    if (controller == null) return;
    if (route.length > 1) {
      await _fitRoute(route, controller);
    } else {
      await controller.animateCamera(CameraUpdate.newCameraPosition(const CameraPosition(target: _bergen, zoom: 10)));
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
        top: 320,
        right: 44,
        bottom: 190,
      ),
    );
  }
}

class _HomePalette {
  const _HomePalette({required this.surface, required this.border, required this.text, required this.muted, required this.shadow});

  factory _HomePalette.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _HomePalette(
      surface: dark ? const Color(0xE60B1620) : const Color(0xEEFFFFFF),
      border: dark ? Colors.white.withValues(alpha: .14) : const Color(0xFFD5DDE4),
      text: dark ? Colors.white : const Color(0xFF12202B),
      muted: dark ? const Color(0xFF9AA9B7) : const Color(0xFF64727D),
      shadow: dark ? Colors.black45 : const Color(0x33000000),
    );
  }

  final Color surface;
  final Color border;
  final Color text;
  final Color muted;
  final Color shadow;
}

class _MapScrim extends StatelessWidget {
  const _MapScrim({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: dark
                  ? const [Color(0xAA071019), Color(0x33071019), Colors.transparent]
                  : const [Color(0x99FFFFFF), Color(0x22FFFFFF), Colors.transparent],
              stops: const [0, .40, 1],
            ),
          ),
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.onProfile, required this.onWeather});

  final AppState state;
  final VoidCallback onProfile;
  final VoidCallback onWeather;

  @override
  Widget build(BuildContext context) {
    final palette = _HomePalette.of(context);
    final WeatherPoint? weather = state.weather.isEmpty ? null : state.weather.first;
    final start = state.activeTrip?.start.trim() ?? '';
    final location = start.isNotEmpty ? start : 'Vær';
    final String? avatarUrl = state.profile?.avatarUrl?.toString();
    return Row(
      children: [
        const Expanded(child: Align(alignment: Alignment.centerLeft, child: GoViaLogo(compact: true))),
        InkWell(
          onTap: onWeather,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 7, 9, 7),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: palette.border),
              boxShadow: [BoxShadow(color: palette.shadow, blurRadius: 12, offset: const Offset(0, 5))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_weatherIcon(weather?.symbolCode ?? ''), color: GoViaColors.orange, size: 21),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(weather == null ? '--' : '${weather.temperature.round()}°', style: TextStyle(color: palette.text, fontWeight: FontWeight.w900, fontSize: 13)),
                    SizedBox(
                      width: 52,
                      child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.muted, fontSize: 9.5)),
                    ),
                  ],
                ),
                const SizedBox(width: 1),
                Icon(Icons.chevron_right_rounded, size: 17, color: palette.muted),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onProfile,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: GoViaColors.orange, shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 21,
              backgroundColor: Theme.of(context).colorScheme.surface,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl != null && avatarUrl.isNotEmpty ? null : Icon(Icons.person_rounded, color: palette.text),
            ),
          ),
        ),
      ],
    );
  }

  static IconData _weatherIcon(String symbol) {
    final value = symbol.toLowerCase();
    if (value.contains('rain') || value.contains('sleet')) return Icons.grain_rounded;
    if (value.contains('snow')) return Icons.ac_unit_rounded;
    if (value.contains('cloud')) return Icons.cloud_rounded;
    if (value.contains('sun') || value.contains('clear')) return Icons.wb_sunny_rounded;
    return Icons.cloud_queue_rounded;
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap, required this.onFilter});

  final VoidCallback onTap;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final palette = _HomePalette.of(context);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      elevation: 5,
      shadowColor: palette.shadow,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 54,
          padding: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: palette.border)),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 28, color: palette.text),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Søk etter destinasjon, sted eller adresse',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.muted, fontSize: 15),
                ),
              ),
              Container(width: 1, height: 30, color: palette.border),
              IconButton(onPressed: onFilter, tooltip: 'Oppdag og filtrer turer', icon: Icon(Icons.tune_rounded, color: palette.text)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryChip extends StatelessWidget {
  const _DiscoveryChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _HomePalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(999),
        elevation: 3,
        shadowColor: palette.shadow,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: palette.border)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: GoViaColors.orange),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: palette.text, fontWeight: FontWeight.w800, fontSize: 11.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripDiscoveryCarousel extends StatelessWidget {
  const _TripDiscoveryCarousel({required this.routes});

  final List<PublishedRoute> routes;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = (width * .53).clamp(194.0, 232.0);
    return SizedBox(
      height: 205,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: routes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) => SizedBox(width: cardWidth, child: _TripDiscoveryCard(route: routes[index])),
      ),
    );
  }
}

class _TripDiscoveryCard extends StatelessWidget {
  const _TripDiscoveryCard({required this.route});

  final PublishedRoute route;

  @override
  Widget build(BuildContext context) {
    final photo = route.photoUrls.firstOrNull;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      elevation: 7,
      shadowColor: Colors.black38,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.publishedRoute, arguments: route),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null)
              Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _TripCardFallback())
            else
              const _TripCardFallback(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x11000000), Color(0x22000000), Color(0xE6000000)],
                  stops: [0, .46, 1],
                ),
              ),
            ),
            Positioned(
              top: 11,
              left: 11,
              right: 11,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xBB1A3346), borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_tagIcon(route), color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Flexible(child: Text(_tag(route), overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800))),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 13,
              right: 13,
              bottom: 11,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    route.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17.5, height: 1.05, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Colors.black87, blurRadius: 5)]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.route_rounded, size: 15, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('${(route.distanceMeters / 1000).round()} km', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(width: 8),
                      const Icon(Icons.schedule_rounded, size: 15, color: Colors.white),
                      const SizedBox(width: 4),
                      Expanded(child: Text(_duration(route.durationSeconds), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white))),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF071019), size: 21),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _tag(PublishedRoute route) {
    if (route.tags.isNotEmpty) {
      final value = route.tags.first.trim();
      if (value.isNotEmpty) return value;
    }
    return transportLabel(route.transport);
  }

  static IconData _tagIcon(PublishedRoute route) => switch (route.transport) {
        StageTransport.motorcycle => Icons.alt_route_rounded,
        StageTransport.car => Icons.directions_car_rounded,
        StageTransport.walking => Icons.hiking_rounded,
        StageTransport.cycling => Icons.pedal_bike_rounded,
        StageTransport.train => Icons.train_rounded,
        StageTransport.ferry => Icons.directions_boat_rounded,
      };

  static String _duration(int seconds) {
    final minutes = math.max(0, seconds ~/ 60);
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours <= 0) return '${math.max(1, rest)}m';
    if (rest == 0) return '${hours}t';
    return '${hours}t ${rest}m';
  }
}

class _TripCardFallback extends StatelessWidget {
  const _TripCardFallback();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF16435A), Color(0xFF0B2535), Color(0xFF071019)],
          ),
        ),
        child: Center(child: Icon(Icons.landscape_rounded, size: 58, color: Color(0x557EE4FF))),
      );
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _HomePalette.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(17),
        elevation: 7,
        shadowColor: palette.shadow,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(17), border: Border.all(color: palette.border)),
            child: Icon(icon, color: palette.text, size: 26),
          ),
        ),
      ),
    );
  }
}

class _DestinationSearchSheet extends StatefulWidget {
  const _DestinationSearchSheet();

  @override
  State<_DestinationSearchSheet> createState() => _DestinationSearchSheetState();
}

class _DestinationSearchSheetState extends State<_DestinationSearchSheet> {
  final controller = TextEditingController();
  final service = const PlaceSearchService();
  Timer? debounce;
  int generation = 0;
  bool searching = false;
  String? error;
  List<PlaceSearchResult> results = const [];

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    debounce?.cancel();
    error = null;
    if (value.trim().length < 2) {
      generation++;
      setState(() {
        searching = false;
        results = const [];
      });
      return;
    }
    final request = ++generation;
    debounce = Timer(const Duration(milliseconds: 300), () => _search(value, request));
  }

  Future<void> _search(String query, int request) async {
    if (!mounted) return;
    setState(() {
      searching = true;
      error = null;
    });
    try {
      final next = await service.search(query, limit: 7);
      if (!mounted || request != generation) return;
      setState(() => results = next);
    } catch (_) {
      if (!mounted || request != generation) return;
      setState(() {
        results = const [];
        error = 'Kunne ikke søke etter steder akkurat nå.';
      });
    } finally {
      if (mounted && request == generation) setState(() => searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, math.max(18.0, bottom + 12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hvor vil du reise?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Søk etter destinasjon, sted eller adresse',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : controller.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            controller.clear();
                            _onChanged('');
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (results.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: math.min(340.0, MediaQuery.sizeOf(context).height * .48)),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final result = results[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined, color: GoViaColors.orange),
                    title: Text(result.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${result.point.lat.toStringAsFixed(5)}, ${result.point.lon.toStringAsFixed(5)}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pop(context, result),
                  );
                },
              ),
            ),
          ] else if (!searching && controller.text.trim().length >= 2 && error == null) ...[
            const SizedBox(height: 14),
            const Text('Ingen steder funnet.'),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
