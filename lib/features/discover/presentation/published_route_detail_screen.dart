import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../domain/models.dart';

class PublishedRouteDetailScreen extends StatefulWidget {
  const PublishedRouteDetailScreen({super.key, required this.route});

  final PublishedRoute? route;

  @override
  State<PublishedRouteDetailScreen> createState() =>
      _PublishedRouteDetailScreenState();
}

class _PublishedRouteDetailScreenState
    extends State<PublishedRouteDetailScreen> {
  PublishedRoute? route;
  ElevationProfile? elevation;
  bool busy = false;
  String? elevationError;

  @override
  void initState() {
    super.initState();
    route = widget.route;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final initial = route;
    if (initial == null) {
      return;
    }

    setState(() => busy = true);
    try {
      final fresh =
          await AppScope.of(context).refreshPublishedRouteDetail(initial.id);
      if (!mounted) {
        return;
      }
      setState(() => route = fresh);
      await _loadElevation(fresh);
    } catch (_) {
      await _loadElevation(initial);
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _loadElevation(PublishedRoute value) async {
    if (value.geometry.length < 2) {
      return;
    }

    try {
      final data = await AppScope.of(context).loadElevationProfile(value);
      if (!mounted) {
        return;
      }
      setState(() {
        elevation = data;
        elevationError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => elevationError =
              'Høydeprofil er ikke tilgjengelig akkurat nå.',
        );
      }
    }
  }

  Future<void> _rate() async {
    final value = route;
    if (value == null || !value.allowRatings) {
      return;
    }

    var experience = value.myRating?.experience.round() ?? 0;
    var scenery = value.myRating?.scenery.round() ?? 0;
    var surface = value.myRating?.surface.round() ?? 0;

    final result = await showModalBottomSheet<RouteRating>(
      context: context,
      backgroundColor: GoViaColors.panel,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vurder turen',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _RatingInput(
                'Opplevelse',
                experience,
                (value) => setSheet(() => experience = value),
              ),
              _RatingInput(
                'Landskap',
                scenery,
                (value) => setSheet(() => scenery = value),
              ),
              _RatingInput(
                _surfaceLabel(value.transport),
                surface,
                (value) => setSheet(() => surface = value),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: experience > 0 && scenery > 0 && surface > 0
                      ? () => Navigator.pop(
                            context,
                            RouteRating(
                              experience: experience.toDouble(),
                              scenery: scenery.toDouble(),
                              surface: surface.toDouble(),
                            ),
                          )
                      : null,
                  child: const Text('Lagre vurdering'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() => busy = true);
    try {
      final fresh = await AppScope.of(context).setPublishedRouteRating(
        value,
        experience: result.experience.round(),
        scenery: result.scenery.round(),
        surface: result.surface.round(),
      );
      if (mounted) {
        setState(() => route = fresh);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _drive() async {
    final value = route;
    if (value == null) {
      return;
    }

    await AppScope.of(context).clonePublishedRoute(value);
    if (!mounted) {
      return;
    }

    final stage = AppScope.of(context).activeTrip?.stages.firstOrNull;
    if (stage != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.routeOverview,
        arguments: stage,
      );
    }
  }

  Future<void> _toggleSaved(PublishedRoute value) async {
    final saved = !value.saved;
    await AppScope.of(context).setPublishedRouteFavorite(value, saved);
    if (mounted) {
      setState(() => route = _copyWithSaved(value, saved));
    }
  }

  PublishedRoute _copyWithSaved(PublishedRoute value, bool saved) {
    return PublishedRoute(
      id: value.id,
      title: value.title,
      authorId: value.authorId,
      authorName: value.authorName,
      transport: value.transport,
      start: value.start,
      end: value.end,
      distanceMeters: value.distanceMeters,
      durationSeconds: value.durationSeconds,
      description: value.description,
      geometry: value.geometry,
      tags: value.tags,
      photos: value.photos,
      saved: saved,
      ratingCount: value.ratingCount,
      rating: value.rating,
      myRating: value.myRating,
      allowRatings: value.allowRatings,
      visibility: value.visibility,
      status: value.status,
      sourceTripId: value.sourceTripId,
      sourceStageId: value.sourceStageId,
    );
  }

  String _duration(int seconds) {
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return hours > 0 ? '${hours}t ${remainder}m' : '${remainder}m';
  }

  @override
  Widget build(BuildContext context) {
    final value = route;
    if (value == null) {
      return const Scaffold(
        body: Center(child: Text('Ruten finnes ikke.')),
      );
    }

    final rating = value.rating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turdetaljer'),
        actions: [
          IconButton(
            onPressed: () => _toggleSaved(value),
            icon: Icon(
              value.saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 36),
          children: [
            if (busy) const LinearProgressIndicator(minHeight: 2),
            Text(
              value.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${value.authorName} · ${transportLabel(value.transport)}',
              style: const TextStyle(color: GoViaColors.muted),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    Icons.straighten_rounded,
                    '${(value.distanceMeters / 1000).round()} km',
                    'Distanse',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Metric(
                    Icons.schedule_rounded,
                    _duration(value.durationSeconds),
                    'Tid',
                  ),
                ),
                if (value.ratingCount > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Metric(
                      Icons.star_rounded,
                      rating?.overall.toStringAsFixed(1) ?? '–',
                      '${value.ratingCount} vurderinger',
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: RouteMapCard(
                height: 300,
                points: value.geometry,
                connectPoints: value.geometry.length >= 2,
                label: value.title,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleSaved(value),
                    icon: Icon(
                      value.saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_add_outlined,
                    ),
                    label: Text(value.saved ? 'Lagret' : 'Lagre'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _drive,
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text('Kjør ruta'),
                  ),
                ),
              ],
            ),
            if (value.description.isNotEmpty) ...[
              const SizedBox(height: 26),
              const _SectionTitle('Om turen'),
              const SizedBox(height: 8),
              Text(value.description, style: const TextStyle(height: 1.45)),
            ],
            if (value.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 26),
              const _SectionTitle('Bilder fra turen'),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: value.photoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      value.photoUrls[index],
                      width: 280,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 280,
                        color: GoViaColors.panel,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            const _SectionTitle('Vurdering'),
            const SizedBox(height: 10),
            if (rating == null || value.ratingCount == 0)
              const Text(
                'Ingen vurderinger ennå.',
                style: TextStyle(color: GoViaColors.muted),
              )
            else ...[
              _RatingView('Opplevelse', rating.experience),
              _RatingView('Landskap', rating.scenery),
              _RatingView(_surfaceLabel(value.transport), rating.surface),
              Text(
                '${value.ratingCount} vurderinger',
                style: const TextStyle(color: GoViaColors.muted),
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: value.allowRatings && !busy ? _rate : null,
              icon: const Icon(Icons.star_outline_rounded),
              label: Text(
                value.myRating == null
                    ? 'Vurder turen'
                    : 'Endre min vurdering',
              ),
            ),
            if (value.tags.isNotEmpty) ...[
              const SizedBox(height: 28),
              const _SectionTitle('Egenskaper'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in value.tags)
                    StatusPill(tag, icon: _tagIcon(tag)),
                ],
              ),
            ],
            const SizedBox(height: 28),
            const _SectionTitle('Høydeprofil'),
            const SizedBox(height: 10),
            if (elevation != null)
              _Elevation(profile: elevation!)
            else
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: GoViaColors.panel,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  elevationError ?? 'Henter høydeprofil …',
                  style: const TextStyle(color: GoViaColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.icon, this.value, this.label);

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GoViaColors.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: GoViaColors.orange),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: GoViaColors.muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingInput extends StatelessWidget {
  const _RatingInput(this.label, this.value, this.onChanged);

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        for (var index = 1; index <= 5; index++)
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(index),
            icon: Icon(
              index <= value
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: GoViaColors.orange,
            ),
          ),
      ],
    );
  }
}

class _RatingView extends StatelessWidget {
  const _RatingView(this.label, this.value);

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: GoViaColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (var index = 1; index <= 5; index++)
            Icon(
              index <= value.round()
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: GoViaColors.orange,
              size: 23,
            ),
        ],
      ),
    );
  }
}

class _Elevation extends StatelessWidget {
  const _Elevation({required this.profile});

  final ElevationProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GoViaColors.panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '↑ ${profile.ascentMeters} m',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: Text(
                  '↓ ${profile.descentMeters} m',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 165,
            width: double.infinity,
            child: CustomPaint(
              painter: _ElevationPainter(profile.samples),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Min ${profile.minElevationMeters} m · '
            'Maks ${profile.maxElevationMeters} m',
            style: const TextStyle(
              color: GoViaColors.muted,
              fontSize: 12,
            ),
          ),
          const Text(
            'Høydedata: Open-Meteo / Copernicus DEM GLO-90',
            style: TextStyle(
              color: GoViaColors.muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  _ElevationPainter(this.samples);

  final List<ElevationSample> samples;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) {
      return;
    }

    final minElevation =
        samples.map((sample) => sample.elevationMeters).reduce(math.min).toDouble();
    final maxElevation =
        samples.map((sample) => sample.elevationMeters).reduce(math.max).toDouble();
    final maxDistance = math.max(1, samples.last.distanceMeters).toDouble();
    final range = math.max(1, maxElevation - minElevation);

    final path = Path();
    for (var index = 0; index < samples.length; index++) {
      final sample = samples[index];
      final x = size.width * sample.distanceMeters / maxDistance;
      final y = size.height -
          ((sample.elevationMeters - minElevation) / range * (size.height - 10)) -
          5;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()..color = GoViaColors.orange.withValues(alpha: 0.16),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = GoViaColors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ElevationPainter oldDelegate) {
    return oldDelegate.samples != samples;
  }
}

String _surfaceLabel(StageTransport transport) {
  return switch (transport) {
    StageTransport.walking => 'Underlag',
    StageTransport.cycling => 'Underlag',
    StageTransport.train => 'Komfort',
    _ => 'Vei / underlag',
  };
}

IconData _tagIcon(String tag) {
  final value = tag.toLowerCase();
  if (value.contains('fjell')) {
    return Icons.landscape_outlined;
  }
  if (value.contains('sjø') ||
      value.contains('innsjø') ||
      value.contains('elv')) {
    return Icons.water_outlined;
  }
  if (value.contains('sving')) {
    return Icons.alt_route_rounded;
  }
  if (value.contains('skog')) {
    return Icons.forest_outlined;
  }
  return Icons.sell_outlined;
}
