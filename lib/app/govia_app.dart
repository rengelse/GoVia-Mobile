import 'dart:async';
import 'package:flutter/material.dart';
import '../features/offline/data/offline_map_controller.dart';
import '../features/notifications/domain/govia_notification.dart';
import '../core/display/screen_preferences.dart';
import '../core/display/screen_runtime.dart';
import '../core/config/dev_features.dart';
import '../core/theme/govia_theme.dart';
import '../domain/models.dart';
import '../features/new_trip/domain/plan_trip_request.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/discover/presentation/discover_screen.dart';
import '../features/discover/presentation/publish_route_screen.dart';
import '../features/discover/presentation/published_route_detail_screen.dart';
import '../features/discover/presentation/my_published_routes_screen.dart';
import '../features/discover/presentation/saved_routes_screen.dart';
import '../features/group/presentation/group_live_screen.dart';
import '../features/group/presentation/invitation_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/navigation/presentation/navigation_screen.dart';
import '../features/navigation/presentation/route_overview_screen.dart';
import '../dev/navigation_simulator/navigation_simulator_screen.dart';
import '../features/new_trip/presentation/new_trip_screen.dart';
import '../features/new_trip/presentation/plan_trip_screen.dart';
import '../features/new_trip/presentation/record_ride_screen.dart';
import '../features/new_trip/presentation/round_trip_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/offline/presentation/offline_screen.dart';
import '../features/participants/presentation/participants_screen.dart';
import '../features/poi/presentation/poi_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/trips/presentation/stage_detail_screen.dart';
import '../features/trips/presentation/stages_screen.dart';
import '../features/trips/presentation/trip_detail_screen.dart';
import '../features/trips/presentation/trips_screen.dart';
import '../features/weather/presentation/weather_screen.dart';
import 'app_routes.dart';
import 'app_scope.dart';
import 'app_state.dart';
import 'shell_screen.dart';

class GoViaApp extends StatefulWidget {
  const GoViaApp({super.key, required this.state});
  final AppState state;

  @override
  State<GoViaApp> createState() => _GoViaAppState();
}

class _GoViaAppState extends State<GoViaApp> {
  late final ScreenPreferencesController _screenPreferences;
  late final OfflineMapController _offlineMaps;
  AppState get state => widget.state;
  @override
  void initState() {
    super.initState();
    _screenPreferences = ScreenPreferencesController(state.store);
    _offlineMaps = OfflineMapController(state.store, onReady: (name, tripId) => state.addNotification(GoViaNotification(
      id: 'offline-ready-${DateTime.now().microsecondsSinceEpoch}', type: GoViaNotificationType.offline,
      title: 'Offlinekart klart', body: '$name er lastet ned på denne enheten.', createdAt: DateTime.now(),
      target: GoViaNotificationTarget(type: GoViaNotificationTargetType.offline, tripId: tripId))),
      onFailure: (name, tripId) => state.addNotification(GoViaNotification(
        id: 'offline-failed-${DateTime.now().microsecondsSinceEpoch}', type: GoViaNotificationType.offline,
        title: 'Kartnedlasting mislyktes', body: '$name kunne ikke lastes ned. Åpne offlinekart for å prøve igjen.',
        createdAt: DateTime.now(), target: GoViaNotificationTarget(type: GoViaNotificationTargetType.offline, tripId: tripId))));
    unawaited(_offlineMaps.initialize());
  }
  @override
  void dispose() { _offlineMaps.dispose(); _screenPreferences.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => OfflineMapScope(controller: _offlineMaps, child: ScreenPreferencesScope(
        controller: _screenPreferences,
        child: AppScope(
        state: state,
        child: AnimatedBuilder(
          animation: state,
          builder: (context, _) => MaterialApp(
            title: 'GoVia',
            navigatorObservers: [screenRouteObserver],
            builder: (context, child) => ScreenRuntime(preferences: _screenPreferences, child: child ?? const SizedBox.shrink()),
            debugShowCheckedModeBanner: false,
            theme: buildGoViaTheme(brightness: Brightness.light),
            darkTheme: buildGoViaTheme(),
            themeMode: switch (state.appThemeMode) {
              'light' => ThemeMode.light,
              'dark' => ThemeMode.dark,
              _ => ThemeMode.system,
            },
            // Use home instead of initialRoute. Flutter may build '/' below a
            // non-root initialRoute, which previously allowed Android Back to
            // reveal ShellScreen behind LoginScreen.
            home: state.signedIn ? const ShellScreen() : const LoginScreen(),
            onGenerateRoute: (settings) => _routeFor(settings),
          ),
        ),
      )));

  Route<dynamic> _routeFor(RouteSettings settings) {
    if (settings.name == AppRoutes.navigationSimulator) {
      // Compile-time development gate. GitHub development releases enable this explicitly.
      if (!DevFeatures.navigationSimulator) {
        return MaterialPageRoute(
          builder: (_) => const ShellScreen(),
          settings: const RouteSettings(name: AppRoutes.shell),
        );
      }
      return MaterialPageRoute(
        builder: (_) => const NavigationSimulatorScreen(),
        settings: settings,
      );
    }
    final wantsLogin = settings.name == AppRoutes.login;
    if (!state.signedIn && !wantsLogin) {
      return MaterialPageRoute(
        builder: (_) => const LoginScreen(),
        settings: const RouteSettings(name: AppRoutes.login),
      );
    }

    final page = switch (settings.name) {
      AppRoutes.login => const LoginScreen(),
      AppRoutes.shell => const ShellScreen(),
      AppRoutes.trips => const TripsScreen(),
      AppRoutes.trip => TripDetailScreen(trip: settings.arguments as Trip?),
      AppRoutes.stages => StagesScreen(trip: settings.arguments as Trip?),
      AppRoutes.stage => StageDetailScreen(stage: settings.arguments as Stage?),
      AppRoutes.routeOverview => RouteOverviewScreen(stage: settings.arguments as Stage?),
      AppRoutes.navigation => NavigationScreen(stage: settings.arguments as Stage?),
      AppRoutes.groupLive => const GroupLiveScreen(),
      AppRoutes.invitation => const InvitationScreen(),
      AppRoutes.newTrip => NewTripScreen(transport: settings.arguments as StageTransport?),
      AppRoutes.planTrip => PlanTripScreen(request: settings.arguments as PlanTripRequest? ?? const PlanTripRequest()),
      AppRoutes.roundTrip => const RoundTripScreen(),
      AppRoutes.recordRide => const RecordRideScreen(),
      AppRoutes.weather => const WeatherScreen(),
      AppRoutes.notifications => const NotificationsScreen(),
      AppRoutes.poi => const PoiScreen(),
      AppRoutes.chat => const ChatScreen(),
      AppRoutes.participants => const ParticipantsScreen(),
      AppRoutes.profile => const ProfileScreen(),
      AppRoutes.offline => const OfflineScreen(),
      AppRoutes.history => const HistoryScreen(),
      AppRoutes.discover => const DiscoverScreen(),
      AppRoutes.publishedRoute => PublishedRouteDetailScreen(route: settings.arguments as PublishedRoute?),
      AppRoutes.publishRoute => PublishRouteScreen(args: settings.arguments is PublishRouteArgs ? settings.arguments as PublishRouteArgs : PublishRouteArgs(stage: settings.arguments as Stage?)),
      AppRoutes.savedRoutes => const SavedRoutesScreen(),
      AppRoutes.myPublishedRoutes => const MyPublishedRoutesScreen(),
      _ => state.signedIn ? const ShellScreen() : const LoginScreen(),
    };
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
