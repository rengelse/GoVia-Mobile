import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/govia_theme.dart';
import 'navigation_simulator_screen.dart';

class GoViaNavigationSimulatorApp extends StatelessWidget {
  const GoViaNavigationSimulatorApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => AppScope(
        state: state,
        child: MaterialApp(
          title: 'GoVia Navigation Simulator',
          debugShowCheckedModeBanner: false,
          theme: buildGoViaTheme(),
          home: const NavigationSimulatorScreen(),
        ),
      );
}
