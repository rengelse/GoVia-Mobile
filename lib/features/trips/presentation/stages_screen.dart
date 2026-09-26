import 'package:flutter/material.dart';
import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../domain/models.dart';

class StagesScreen extends StatelessWidget {
  const StagesScreen({super.key, this.trip}); final Trip? trip;
  @override Widget build(BuildContext context) {
    final value = trip ?? AppScope.of(context).activeTrip;
    final stages = [...?value?.stages]..sort((a,b) => a.day != b.day ? a.day.compareTo(b.day) : a.order.compareTo(b.order));
    return GoViaScreen(title: 'Etapper', subtitle: value?.name, child: Column(children: [for (final s in stages) Card(child: ListTile(onTap: () => Navigator.pushNamed(context, AppRoutes.stage, arguments: s), leading: Text('Dag ${s.day}', style: const TextStyle(fontWeight: FontWeight.w900)), title: Text('${s.start} → ${s.end}'), subtitle: Text(transportLabel(s.transport)), trailing: const Icon(Icons.chevron_right))) ]));
  }
}
