import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../app/app_state.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
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

    return Stack(
      fit: StackFit.expand,
      children: [
        MapLibreMap(
          key: ValueKey(_darkMap),
          styleString: _darkMap
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
            _drawRoute(routeGeometry);
          },
          onStyleLoadedCallback: () {
            _mapStyleLoaded = true;
            _drawnRouteKey = null;
            _drawRoute(routeGeometry);
          },
        ),
        const _MapScrim(),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: _TopBar(
                  state: state,
                  onProfile: () => state.setShellIndex(3),
                  onWeather: () => Navigator.pushNamed(context, AppRoutes.weather),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _SearchBar(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.discover),
                  onFilter: () => Navigator.pushNamed(context, AppRoutes.discover),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
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
              const SizedBox(height: 12),
              _TripDiscoveryCarousel(routes: discoveryRoutes),
              const Spacer(),
            ],
          ),
        ),
        Positioned(
          right: 18,
          bottom: 188,
          child: Column(
            children: [
              _MapActionButton(
                icon: Icons.layers_outlined,
                tooltip: _darkMap ? 'Vis standardkart' : 'Vis mørkt kart',
                onTap: () => setState(() {
                  _darkMap = !_darkMap;
                  _mapStyleLoaded = false;
                  _mapController = null;
                  _drawnRouteKey = null;
                }),
              ),
              const SizedBox(height: 10),
              _MapActionButton(icon: Icons.my_location_rounded, tooltip: 'Sentrer kart', onTap: () => _recenter(routeGeometry)),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 104,
          child: Center(
            child: FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.newTrip),
              style: FilledButton.styleFrom(
                backgroundColor: GoViaColors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(236, 60),
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

  Future<void> _drawRoute(List<GeoPoint> route) async {
    final controller = _mapController;
    if (controller == null || !_mapStyleLoaded || route.length < 2) return;
    final key = '${route.length}:${route.first.lat}:${route.first.lon}:${route.last.lat}:${route.last.lon}:$_darkMap';
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
        top: 350,
        right: 44,
        bottom: 180,
      ),
    );
  }
}

class _MapScrim extends StatelessWidget {
  const _MapScrim();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [const Color(0xAA071019), const Color(0x33071019), Colors.transparent],
              stops: const [0, .42, 1],
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
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            decoration: BoxDecoration(
              color: const Color(0xD90B1620),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: .12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_weatherIcon(weather?.symbolCode ?? ''), color: GoViaColors.orange, size: 23),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(weather == null ? '--' : '${weather.temperature.round()}°', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    SizedBox(
                      width: 54,
                      child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GoViaColors.muted, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 18, color: GoViaColors.muted),
              ],
            ),
          ),
        ),
        const SizedBox(width: 9),
        InkWell(
          onTap: onProfile,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: GoViaColors.orange, shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: GoViaColors.panel2,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl != null && avatarUrl.isNotEmpty ? null : const Icon(Icons.person_rounded, color: Colors.white),
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
  Widget build(BuildContext context) => Material(
        color: const Color(0xE60B1620),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 62,
            padding: const EdgeInsets.only(left: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: .16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 31),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Søk etter destinasjoner, ruter eller steder',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Color(0xFFB8C2CC), fontSize: 16),
                  ),
                ),
                Container(width: 1, height: 34, color: Colors.white.withValues(alpha: .12)),
                IconButton(onPressed: onFilter, tooltip: 'Filtrer', icon: const Icon(Icons.tune_rounded)),
              ],
            ),
          ),
        ),
      );
}

class _DiscoveryChip extends StatelessWidget {
  const _DiscoveryChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: const Color(0xD90B1620),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: .16)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 19, color: GoViaColors.orange),
                  const SizedBox(width: 7),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _TripDiscoveryCarousel extends StatelessWidget {
  const _TripDiscoveryCarousel({required this.routes});

  final List<PublishedRoute> routes;

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Material(
          color: const Color(0xE60B1620),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, AppRoutes.discover),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 118,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: .14)),
              ),
              child: const Row(
                children: [
                  CircleAvatar(backgroundColor: Color(0x22FF7A21), child: Icon(Icons.route_rounded, color: GoViaColors.orange)),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Oppdag turer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('Publiserte GoVia-turer vises her når de er tilgjengelige.', style: TextStyle(color: GoViaColors.muted, height: 1.3)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = (width * .56).clamp(205.0, 245.0);
    return SizedBox(
      height: 222,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: routes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
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
      color: GoViaColors.panel,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      shadowColor: Colors.black45,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.publishedRoute, arguments: route),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null)
              Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _TripCardFallback(),
              )
            else
              const _TripCardFallback(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x11000000), Color(0x22000000), Color(0xE6000000)],
                  stops: [0, .48, 1],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xBB1A3346), borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_tagIcon(route), color: Colors.white, size: 15),
                      const SizedBox(width: 5),
                      Flexible(child: Text(_tag(route), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    route.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 19, height: 1.05, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Colors.black87, blurRadius: 5)]),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.route_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('${(route.distanceMeters / 1000).round()} km', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(width: 10),
                      const Icon(Icons.schedule_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Expanded(child: Text(_duration(route.durationSeconds), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white))),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF071019), size: 22),
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
        child: Center(child: Icon(Icons.landscape_rounded, size: 62, color: Color(0x557EE4FF))),
      );
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: const Color(0xE60B1620),
          borderRadius: BorderRadius.circular(18),
          elevation: 8,
          shadowColor: Colors.black45,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: .14)),
              ),
              child: Icon(icon, color: Colors.white, size: 27),
            ),
          ),
        ),
      );
}
