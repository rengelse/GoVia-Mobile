import 'package:flutter/material.dart';
import '../core/theme/govia_theme.dart';
import '../domain/models.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/group/presentation/group_live_screen.dart';
import '../features/group/presentation/invitation_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/navigation/presentation/navigation_screen.dart';
import '../features/navigation/presentation/route_overview_screen.dart';
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

class GoViaApp extends StatelessWidget {
  const GoViaApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => AppScope(
        state: state,
        child: MaterialApp(
          title: 'GoVia',
          debugShowCheckedModeBanner: false,
          theme: buildGoViaTheme(),
          initialRoute: state.signedIn ? AppRoutes.shell : AppRoutes.login,
          onGenerateRoute: (settings) {
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
              AppRoutes.newTrip => const NewTripScreen(),
              AppRoutes.planTrip => const PlanTripScreen(),
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
              _ => const ShellScreen(),
            };
            return MaterialPageRoute(builder: (_) => page, settings: settings);
          },
        ),
      );
}
