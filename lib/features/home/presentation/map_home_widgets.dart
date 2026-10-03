import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app/app_routes.dart';
import '../../../app/app_state.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../domain/models.dart';

class MapHomeScrim extends StatelessWidget {
  const MapHomeScrim({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Theme.of(context).colorScheme.surface.withValues(alpha: .75), Theme.of(context).colorScheme.surface.withValues(alpha: .12), Colors.transparent],
              stops: const [0, .42, 1],
            ),
          ),
        ),
      );
}

class MapHomeTopBar extends StatelessWidget {
  const MapHomeTopBar({super.key, required this.state, required this.onProfile, required this.onWeather});

  final AppState state;
  final VoidCallback onProfile;
  final VoidCallback onWeather;

  @override
  Widget build(BuildContext context) {
    final WeatherPoint? weather = state.mapWeather?.points.firstOrNull;
    final location = state.mapWeatherLoading ? 'Henter vær' : weather == null ? 'Trykk for info' : 'I dag';
    final String? avatarUrl = state.profile?.avatarUrl?.toString();
    return Row(
      children: [
        Expanded(child: Align(alignment: Alignment.centerLeft, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const SizedBox(width: 112, height: 30, child: GoViaLogo(compact: true)),
        ))),
        InkWell(
          onTap: onWeather,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_weatherIcon(weather?.symbolCode ?? ''), color: GoViaColors.orange, size: 23),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.mapWeatherLoading ? '…' : weather == null ? 'Vær' : temperatureLabel(weather), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    SizedBox(
                      width: 76,
                      child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
              radius: 19,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl != null && avatarUrl.isNotEmpty ? null : Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ),
      ],
    );
  }

  static String temperatureLabel(WeatherPoint weather) {
    if (weather.tempMin != null && weather.tempMax != null) return '${weather.tempMin!.round()}–${weather.tempMax!.round()}°';
    return '${weather.temperature.round()}°';
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

class MapHomeSearchBar extends StatelessWidget {
  const MapHomeSearchBar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 50,
            padding: const EdgeInsets.only(left: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Søk etter destinasjon, sted eller adresse',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.chevron_right_rounded)),
              ],
            ),
          ),
        ),
      );
}

class MapDiscoveryChip extends StatelessWidget {
  const MapDiscoveryChip({super.key, required this.icon, required this.label, required this.onTap, this.selected = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: selected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surface.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? GoViaColors.orange : Theme.of(context).colorScheme.outlineVariant),
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

class TripDiscoveryCarousel extends StatelessWidget {
  const TripDiscoveryCarousel({super.key, required this.routes});

  final List<PublishedRoute> routes;

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = (width * .56).clamp(205.0, 245.0);
    return SizedBox(
      height: 190,
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
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: .2),
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
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withValues(alpha: .92), borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_tagIcon(route), color: Theme.of(context).colorScheme.onSurface, size: 15),
                      const SizedBox(width: 5),
                      Flexible(child: Text(_tag(route), overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface))),
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
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Theme.of(context).colorScheme.secondaryContainer, Theme.of(context).colorScheme.surfaceContainerHighest, Theme.of(context).colorScheme.surface],
          ),
        ),
        child: Center(child: Icon(Icons.landscape_rounded, size: 62, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class MapHomeActionButton extends StatelessWidget {
  const MapHomeActionButton({super.key, required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(18),
          elevation: 8,
          shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: .2),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 24),
            ),
          ),
        ),
      );
}
