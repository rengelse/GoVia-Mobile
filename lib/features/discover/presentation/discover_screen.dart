import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../domain/models.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  StageTransport? transportFilter;
  double? maxDistanceKm;
  double? maxDurationHours;
  bool onlyWithPhotos = false;
  bool refreshing = false;
  bool loaded = false;
  Position? position;
  String? locationMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      loaded = true;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (refreshing) return;
    setState(() => refreshing = true);
    final state = AppScope.of(context);
    await Future.wait([
      state.refreshPublishedRoutes(),
      _refreshPosition(),
    ]);
    if (mounted) setState(() => refreshing = false);
  }

  Future<void> _refreshPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => locationMessage = 'Posisjonstjenester er slått av.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => locationMessage = 'Gi posisjonstilgang for å se turer nær deg.');
        return;
      }
      final value = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) {
        setState(() {
          position = value;
          locationMessage = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => locationMessage = 'Kunne ikke hente posisjonen din akkurat nå.');
    }
  }

  List<PublishedRoute> _filtered(List<PublishedRoute> source) {
    return source.where((route) {
      if (route.transport == StageTransport.ferry) return false;
      if (transportFilter != null && route.transport != transportFilter) return false;
      if (maxDistanceKm != null && route.distanceMeters > maxDistanceKm! * 1000) return false;
      if (maxDurationHours != null && route.durationSeconds > maxDurationHours! * 3600) return false;
      if (onlyWithPhotos && route.photoUrls.isEmpty) return false;
      return true;
    }).toList(growable: false);
  }

  List<_NearbyRoute> _nearby(List<PublishedRoute> source) {
    final current = position;
    if (current == null) return const [];
    final rows = source
        .where((route) => route.geometry.isNotEmpty)
        .map((route) {
          final first = route.geometry.first;
          final meters = _distanceMeters(current.latitude, current.longitude, first.lat, first.lon);
          return _NearbyRoute(route: route, distanceMeters: meters);
        })
        .where((row) => row.distanceMeters <= 300000)
        .toList(growable: false)
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return rows;
  }

  Future<void> _showFilters() async {
    var draftTransport = transportFilter;
    var draftDistance = maxDistanceKm;
    var draftDuration = maxDurationHours;
    var draftPhotos = onlyWithPhotos;
    final result = await showModalBottomSheet<_DiscoverFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GoViaColors.panel,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Filtrer turer', style: Theme.of(context).textTheme.titleLarge)),
                    TextButton(
                      onPressed: () => setModalState(() {
                        draftTransport = null;
                        draftDistance = null;
                        draftDuration = null;
                        draftPhotos = false;
                      }),
                      child: const Text('Nullstill'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Transport', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(label: const Text('Alle'), selected: draftTransport == null, onSelected: (_) => setModalState(() => draftTransport = null)),
                    for (final value in _discoverTransports)
                      ChoiceChip(
                        label: Text(transportLabel(value)),
                        selected: draftTransport == value,
                        onSelected: (_) => setModalState(() => draftTransport = value),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('Maks rutelengde', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final value in <double?>[null, 50, 150, 300])
                      ChoiceChip(
                        label: Text(value == null ? 'Alle' : '${value.round()} km'),
                        selected: draftDistance == value,
                        onSelected: (_) => setModalState(() => draftDistance = value),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('Maks varighet', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final value in <double?>[null, 2, 5, 10])
                      ChoiceChip(
                        label: Text(value == null ? 'Alle' : '${value.round()} t'),
                        selected: draftDuration == value,
                        onSelected: (_) => setModalState(() => draftDuration = value),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kun turer med bilder'),
                  value: draftPhotos,
                  onChanged: (value) => setModalState(() => draftPhotos = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _DiscoverFilter(
                        transport: draftTransport,
                        maxDistanceKm: draftDistance,
                        maxDurationHours: draftDuration,
                        onlyWithPhotos: draftPhotos,
                      ),
                    ),
                    child: const Text('Vis turer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      transportFilter = result.transport;
      maxDistanceKm = result.maxDistanceKm;
      maxDurationHours = result.maxDurationHours;
      onlyWithPhotos = result.onlyWithPhotos;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final routes = _filtered(state.publishedRoutes);
    final nearby = _nearby(routes);
    final content = RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, widget.embedded ? 18 : 8, 18, 110),
        children: [
          if (widget.embedded) ...[
            Row(
              children: [
                Expanded(child: Text('Oppdag', style: Theme.of(context).textTheme.headlineMedium)),
                IconButton(
                  tooltip: 'Filtrer',
                  onPressed: _showFilters,
                  icon: Badge(isLabelVisible: _filtersActive, child: const Icon(Icons.filter_alt_outlined)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Finn ruter fra GoVia-fellesskapet.', style: TextStyle(color: GoViaColors.muted)),
            const SizedBox(height: 22),
          ],
          _sectionHeader(
            context,
            'Nær meg',
            position == null ? 'Oppdag ruter rundt posisjonen din' : 'Offentlige ruter innen 300 km',
            trailing: position == null
                ? TextButton.icon(onPressed: _refreshPosition, icon: const Icon(Icons.my_location, size: 18), label: const Text('Bruk posisjon'))
                : null,
          ),
          if (locationMessage != null) ...[
            const SizedBox(height: 4),
            Text(locationMessage!, style: const TextStyle(color: GoViaColors.muted)),
          ],
          const SizedBox(height: 12),
          if (position != null && nearby.isEmpty)
            const _EmptyCommunity(text: 'Ingen publiserte turer i nærheten matcher filteret ditt.')
          else if (nearby.isNotEmpty)
            _RouteCarousel(
              itemCount: nearby.length,
              itemBuilder: (context, index) {
                final row = nearby[index];
                return _CommunityRouteCard(
                  route: row.route,
                  proximityMeters: row.distanceMeters,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.publishedRoute, arguments: row.route),
                );
              },
            ),
          const SizedBox(height: 30),
          _sectionHeader(context, 'Globalt', 'Turer publisert av GoVia-fellesskapet'),
          const SizedBox(height: 12),
          if (routes.isEmpty)
            const _EmptyCommunity(text: 'Ingen publiserte turer matcher filteret ditt ennå.')
          else
            _RouteCarousel(
              itemCount: routes.length,
              itemBuilder: (context, index) {
                final route = routes[index];
                return _CommunityRouteCard(
                  route: route,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.publishedRoute, arguments: route),
                );
              },
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.savedRoutes),
                  icon: const Icon(Icons.bookmark_outline),
                  label: const Text('Lagrede'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.myPublishedRoutes),
                  icon: const Icon(Icons.public_outlined),
                  label: const Text('Mine publiserte'),
                ),
              ),
            ],
          ),
          if (refreshing) ...[
            const SizedBox(height: 18),
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oppdag'),
        actions: [
          IconButton(
            tooltip: 'Filtrer',
            onPressed: _showFilters,
            icon: Badge(isLabelVisible: _filtersActive, child: const Icon(Icons.filter_alt_outlined)),
          ),
        ],
      ),
      body: content,
    );
  }

  bool get _filtersActive => transportFilter != null || maxDistanceKm != null || maxDurationHours != null || onlyWithPhotos;

  Widget _sectionHeader(BuildContext context, String title, String subtitle, {Widget? trailing}) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: GoViaColors.muted)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      );
}

const _discoverTransports = <StageTransport>[
  StageTransport.motorcycle,
  StageTransport.car,
  StageTransport.cycling,
  StageTransport.walking,
  StageTransport.train,
];

class _RouteCarousel extends StatelessWidget {
  const _RouteCarousel({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 356,
        child: Scrollbar(
          thumbVisibility: false,
          child: ListView.separated(
            primary: false,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: itemBuilder,
          ),
        ),
      );
}

class _CommunityRouteCard extends StatelessWidget {
  const _CommunityRouteCard({required this.route, required this.onTap, this.proximityMeters});
  final PublishedRoute route;
  final VoidCallback onTap;
  final double? proximityMeters;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = route.photoUrls.isNotEmpty;
    final cardWidth = (MediaQuery.sizeOf(context).width * .78).clamp(270.0, 310.0);
    return SizedBox(
      width: cardWidth,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 190,
                width: double.infinity,
                child: hasPhoto
                    ? Image.network(
                        route.photoUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => RouteMapCard(height: 190, points: route.geometry, label: transportLabel(route.transport)),
                      )
                    : RouteMapCard(height: 190, points: route.geometry, label: transportLabel(route.transport)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              route.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(_iconFor(route.transport), size: 19, color: GoViaColors.cyan),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        route.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: GoViaColors.muted),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.route_outlined, size: 17, color: GoViaColors.muted),
                          const SizedBox(width: 5),
                          Text('${(route.distanceMeters / 1000).round()} km'),
                          const SizedBox(width: 14),
                          const Icon(Icons.schedule_outlined, size: 17, color: GoViaColors.muted),
                          const SizedBox(width: 5),
                          Text(_duration(route.durationSeconds)),
                        ],
                      ),
                      if (proximityMeters != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.near_me_outlined, size: 17, color: GoViaColors.cyan),
                            const SizedBox(width: 5),
                            Text('${(proximityMeters! / 1000).round()} km unna deg', style: const TextStyle(color: GoViaColors.muted)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(StageTransport value) => switch (value) {
        StageTransport.motorcycle => Icons.two_wheeler,
        StageTransport.car => Icons.directions_car,
        StageTransport.walking => Icons.directions_walk,
        StageTransport.cycling => Icons.pedal_bike,
        StageTransport.train => Icons.train,
        StageTransport.ferry => Icons.directions_boat,
      };

  static String _duration(int seconds) {
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return hours > 0 ? '${hours}t ${rest}m' : '${rest}m';
  }
}

class _EmptyCommunity extends StatelessWidget {
  const _EmptyCommunity({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              const Icon(Icons.explore_outlined, color: GoViaColors.cyan, size: 34),
              const SizedBox(width: 14),
              Expanded(child: Text(text, style: const TextStyle(color: GoViaColors.muted))),
            ],
          ),
        ),
      );
}

class _NearbyRoute {
  const _NearbyRoute({required this.route, required this.distanceMeters});
  final PublishedRoute route;
  final double distanceMeters;
}

class _DiscoverFilter {
  const _DiscoverFilter({required this.transport, required this.maxDistanceKm, required this.maxDurationHours, required this.onlyWithPhotos});
  final StageTransport? transport;
  final double? maxDistanceKm;
  final double? maxDurationHours;
  final bool onlyWithPhotos;
}

double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const radius = 6371000.0;
  final dLat = _radians(lat2 - lat1);
  final dLon = _radians(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(_radians(lat1)) * math.cos(_radians(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _radians(double value) => value * math.pi / 180;
