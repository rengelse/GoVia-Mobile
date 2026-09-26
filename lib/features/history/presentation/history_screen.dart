import 'package:flutter/material.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => const GoViaScreen(
        title: 'Historikk',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RouteMapCard(height: 220, label: 'Tidligere turer'),
            SizedBox(height: 18),
            _HistoryTrip('Vestland rundt', '4.–7. juli', '611 km', '14 t 20 min'),
            _HistoryTrip('Sørlandet', '18. juni', '384 km', '8 t 05 min'),
            _HistoryTrip('Jæren søndagstur', '2. juni', '178 km', '3 t 44 min'),
          ],
        ),
      );
}

class _HistoryTrip extends StatelessWidget {
  const _HistoryTrip(this.name, this.date, this.distance, this.duration);
  final String name;
  final String date;
  final String distance;
  final String duration;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0x2210A9FF),
              child: Icon(Icons.two_wheeler, color: GoViaColors.blue),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('$date · $distance · $duration'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      );
}
