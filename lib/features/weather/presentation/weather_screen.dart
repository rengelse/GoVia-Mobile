import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../domain/models.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).refreshTripWeather();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final trip = state.activeTrip;
    final List<WeatherPoint> weather = state.weatherTripId == trip?.id ? state.weather : const <WeatherPoint>[];
    final date = state.weatherForecastDate;
    final subtitle = trip == null
        ? 'Vær langs planlagt rute'
        : date == null
            ? trip.name
            : '${trip.name} · ${DateFormat('dd.MM').format(date)}';

    return GoViaScreen(
      title: 'Vær',
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RouteMapCard(height: 230, label: 'Vær langs ruten'),
          const SizedBox(height: 16),
          if (state.weatherLoading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Henter vær langs den planlagte ruten …'),
                  ],
                ),
              ),
            )
          else if (weather.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.cloud_outlined, color: GoViaColors.blue),
                    const SizedBox(width: 12),
                    Expanded(child: Text(state.weatherMessage ?? 'Ingen værdata tilgjengelig for denne turen.')),
                  ],
                ),
              ),
            )
          else ...[
            if ((state.weatherProviderLabel ?? '').isNotEmpty || state.weatherGeneratedAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  [
                    if ((state.weatherProviderLabel ?? '').isNotEmpty) state.weatherProviderLabel!,
                    if (state.weatherGeneratedAt != null) 'oppdatert ${DateFormat('HH:mm').format(state.weatherGeneratedAt!.toLocal())}',
                  ].join(' · '),
                  style: const TextStyle(color: GoViaColors.muted, fontSize: 12),
                ),
              ),
            SizedBox(
              height: 152,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: weather.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final w = weather[i];
                  return Container(
                    width: 126,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: GoViaColors.panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: GoViaColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.label, style: const TextStyle(color: GoViaColors.muted)),
                        const SizedBox(height: 8),
                        Icon(_weatherIcon(w.symbolCode), color: GoViaColors.blue),
                        const Spacer(),
                        Text('${w.temperature.round()}°', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        Text('${w.wind.toStringAsFixed(1)} m/s', style: const TextStyle(color: GoViaColors.muted, fontSize: 12)),
                        Text('${w.precipitation.toStringAsFixed(1)} mm', style: const TextStyle(color: GoViaColors.muted, fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 20),
          const SectionTitle('Ruteinnsikt'),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.route_outlined, color: GoViaColors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'GoVia bruker den planlagte ruten og turdatoen. Prognosen hentes automatisk gjennom GoVia sin værtjeneste når turen er innenfor tilgjengelig prognosevindu.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _weatherIcon(String symbolCode) {
  final value = symbolCode.toLowerCase();
  if (value.contains('thunder')) return Icons.thunderstorm_outlined;
  if (value.contains('snow')) return Icons.ac_unit_outlined;
  if (value.contains('rain') || value.contains('sleet')) return Icons.umbrella_outlined;
  if (value.contains('clear')) return Icons.wb_sunny_outlined;
  return Icons.cloud_outlined;
}
