import 'package:flutter/material.dart';
import '../../../app/app_routes.dart';
import '../../../domain/models.dart';
import '../domain/plan_trip_request.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';

class NewTripScreen extends StatelessWidget {
  const NewTripScreen({super.key, this.embedded = false, this.transport});
  final bool embedded;
  final StageTransport? transport;
  @override Widget build(BuildContext context) {
    final content = ListView(padding: EdgeInsets.fromLTRB(18, embedded ? 18 : 8, 18, 110), children: [
      if (embedded) ...[Text('Ny tur', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 6), const Text('Planlegg, generer eller ta opp.', style: TextStyle(color: GoViaColors.muted)), const SizedBox(height: 18)],
      const RouteMapCard(height: 250, label: 'Planlegg din neste tur'), const SizedBox(height: 14),
      Card(child: ListTile(onTap: () => Navigator.pushNamed(context, AppRoutes.invitation), leading: const CircleAvatar(backgroundColor: Color(0x222DD4FF), child: Icon(Icons.qr_code_scanner, color: GoViaColors.cyan)), title: const Text('Hent fra GoVia Desktop', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Skann sikker QR-kode'), trailing: const Icon(Icons.chevron_right))),
      const SizedBox(height: 18),
      _action(context, Icons.alt_route_rounded, 'Planlegg tur', 'Velg start, stopp og mål. Sammenlign ruter.', AppRoutes.planTrip, GoViaColors.orange),
      _action(context, Icons.loop_rounded, 'Opprett rundtur', 'Velg ønsket lengde eller varighet.', AppRoutes.roundTrip, GoViaColors.blue),
      _action(context, Icons.radio_button_checked_rounded, 'Ta opp tur', 'Registrer den faktiske turen mens du kjører.', AppRoutes.recordRide, GoViaColors.green),
    ]);
    if (embedded) return content;
    return Scaffold(appBar: AppBar(title: const Text('Ny tur')), body: content);
  }
  Widget _action(BuildContext context, IconData icon, String title, String subtitle, String route, Color color) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Card(child: InkWell(borderRadius: BorderRadius.circular(18), onTap: () => Navigator.pushNamed(context, route, arguments: route == AppRoutes.planTrip ? PlanTripRequest(transport: transport) : null), child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Container(width: 54, height: 54, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color, size: 30)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: GoViaColors.muted))])), const Icon(Icons.chevron_right)])))));
}
