import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../domain/models.dart';
import '../domain/plan_trip_request.dart';

class NewTripScreen extends StatelessWidget {
  const NewTripScreen({super.key, this.transport});

  final StageTransport? transport;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Turer')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
          children: [
            const Text(
              'Hva vil du gjøre?',
              style: TextStyle(color: GoViaColors.muted, fontSize: 16),
            ),
            const SizedBox(height: 18),
            _action(
              context,
              Icons.route_rounded,
              'Mine turer',
              'Se planlagte, aktive og tidligere turer.',
              AppRoutes.trips,
              GoViaColors.cyan,
            ),
            _action(
              context,
              Icons.qr_code_scanner_rounded,
              'Hent fra GoVia Desktop',
              'Skann sikker QR-kode.',
              AppRoutes.invitation,
              GoViaColors.cyan,
            ),
            _action(
              context,
              Icons.alt_route_rounded,
              'Planlegg tur',
              'Velg start, stopp og mål. Sammenlign ruter.',
              AppRoutes.planTrip,
              GoViaColors.orange,
            ),
            _action(
              context,
              Icons.loop_rounded,
              'Opprett rundtur',
              'Velg ønsket lengde eller varighet.',
              AppRoutes.roundTrip,
              GoViaColors.blue,
            ),
            _action(
              context,
              Icons.radio_button_checked_rounded,
              'Ta opp tur',
              'Registrer den faktiske turen mens du kjører.',
              AppRoutes.recordRide,
              GoViaColors.green,
            ),
          ],
        ),
      );

  Widget _action(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String route,
    Color color,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.pushNamed(
              context,
              route,
              arguments: route == AppRoutes.planTrip ? PlanTripRequest(transport: transport) : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(subtitle, style: const TextStyle(color: GoViaColors.muted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      );
}
