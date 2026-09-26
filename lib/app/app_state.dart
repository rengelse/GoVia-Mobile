import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/storage/local_store.dart';
import '../domain/models.dart';
import '../features/auth/auth_service.dart';

class AppState extends ChangeNotifier {
  AppState({required this.auth, required this.api, required this.store});
  final AuthService auth;
  final ApiClient api;
  final LocalStore store;

  bool loading = true;
  bool offline = false;
  String? error;
  int shellIndex = 0;
  Trip? activeTrip;
  List<Trip> trips = const [];
  List<ChatMessage> messages = const [];
  List<PoiItem> pois = const [];
  List<WeatherPoint> weather = const [];

  bool get signedIn => auth.signedIn || (AppConfig.devSeed && !auth.configured);

  Future<void> initialize() async {
    loading = true;
    notifyListeners();
    try {
      if (AppConfig.devSeed) _loadDevSeed();
      if (auth.signedIn) await refreshCloud();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setShellIndex(int index) {
    shellIndex = index;
    notifyListeners();
  }

  Future<void> refreshCloud() async {
    if (!auth.signedIn) return;
    // Existing GoVia domain repositories are exposed through /api/v1/domain.
    // Mobile parsing is deliberately tolerant until a dedicated mobile snapshot
    // contract is added server-side.
    try {
      final result = await api.domain('trip', 'list', const []);
      final raw = _unwrapList(result);
      if (raw.isNotEmpty) {
        trips = raw.map(_tripFromLooseJson).toList(growable: false);
        activeTrip = trips.where((t) => t.status == TripStatus.active).firstOrNull ?? trips.firstOrNull;
      }
      offline = false;
      error = null;
    } catch (e) {
      offline = true;
      error = 'Cloud-sync utilgjengelig. Viser lokal data der den finnes.';
    }
    notifyListeners();
  }

  Future<void> selectTrip(Trip trip) async {
    activeTrip = trip;
    await store.writeString('active_trip_id', trip.id);
    notifyListeners();
  }

  Future<void> addLocalTrip(Trip trip) async {
    trips = [trip, ...trips.where((t) => t.id != trip.id)];
    activeTrip = trip;
    notifyListeners();
  }

  void addMessage(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    messages = [
      ...messages,
      ChatMessage(id: DateTime.now().microsecondsSinceEpoch.toString(), sender: 'Du', text: clean, sentAt: DateTime.now(), mine: true),
    ];
    notifyListeners();
  }

  void _loadDevSeed() {
    final now = DateTime.now();
    final stages = [
      Stage(
        id: 'stage-0', day: 0, order: 0, start: 'Bergen', end: 'Kristiansand', transport: StageTransport.motorcycle,
        distanceMeters: 462000, durationSeconds: 7 * 3600 + 15 * 60,
        routeCandidates: const [
          RouteCandidate(id: 'r0a', name: 'Anbefalt', distanceMeters: 462000, durationSeconds: 26100, official: true, geometry: [GeoPoint(lat:60.3913,lon:5.3221),GeoPoint(lat:60.10,lon:6.10),GeoPoint(lat:59.65,lon:6.35),GeoPoint(lat:59.00,lon:5.75),GeoPoint(lat:58.45,lon:6.00),GeoPoint(lat:58.1467,lon:7.9956)]),
          RouteCandidate(id: 'r0b', name: 'Svingete', distanceMeters: 489000, durationSeconds: 28200),
          RouteCandidate(id: 'r0c', name: 'Alternativ', distanceMeters: 475000, durationSeconds: 27300),
        ], officialRouteId: 'r0a',
      ),
      const Stage(id: 'stage-1', day: 1, order: 0, start: 'Kristiansand', end: 'Hirtshals', transport: StageTransport.ferry, distanceMeters: 0, durationSeconds: 3 * 3600 + 15 * 60),
      const Stage(id: 'stage-2', day: 1, order: 1, start: 'Hirtshals', end: 'Aalborg', transport: StageTransport.motorcycle, distanceMeters: 71000, durationSeconds: 3900),
      const Stage(id: 'stage-3', day: 2, order: 0, start: 'Aalborg', end: 'Skagen', transport: StageTransport.motorcycle, distanceMeters: 108000, durationSeconds: 6600),
    ];
    final trip = Trip(
      id: 'trip-demo',
      name: 'Norge → Danmark',
      startDate: DateTime(now.year, now.month, now.day),
      endDate: DateTime(now.year, now.month, now.day + 4),
      start: 'Bergen',
      end: 'Skagen',
      status: TripStatus.active,
      stages: stages,
      offlineReady: true,
      participants: const [
        Participant(id: 'p1', name: 'Rengelse', role: 'owner', online: true),
        Participant(id: 'p2', name: 'Marius', online: true),
        Participant(id: 'p3', name: 'Lise', online: false),
      ],
    );
    trips = [trip];
    activeTrip = trip;
    messages = [
      ChatMessage(id: 'm1', sender: 'Marius', text: 'Klar for avgang 08:00?', sentAt: now.subtract(const Duration(minutes: 18))),
      ChatMessage(id: 'm2', sender: 'Du', text: 'Jepp. Vi møtes ved bensinstasjonen.', sentAt: now.subtract(const Duration(minutes: 11)), mine: true),
    ];
    pois = const [
      PoiItem(id: 'poi-1', name: 'Circle K Mandal', category: 'Drivstoff', distanceMeters: 23800),
      PoiItem(id: 'poi-2', name: 'Fjordkafé', category: 'Kaffe', distanceMeters: 41700),
      PoiItem(id: 'poi-3', name: 'Kristiansand fergeterminal', category: 'Ferge', distanceMeters: 62000),
    ];
    weather = const [
      WeatherPoint(label: '08', temperature: 12, wind: 4, precipitation: .1),
      WeatherPoint(label: '11', temperature: 15, wind: 5, precipitation: .0),
      WeatherPoint(label: '14', temperature: 17, wind: 7, precipitation: .3),
      WeatherPoint(label: '17', temperature: 14, wind: 8, precipitation: 1.2),
    ];
  }

  List<Map<String, dynamic>> _unwrapList(Map<String, dynamic> result) {
    final data = result['data'] ?? result['result'] ?? result;
    if (data is List) return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (data is Map && data['items'] is List) return (data['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return const [];
  }

  Trip _tripFromLooseJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['trip_id'] ?? DateTime.now().microsecondsSinceEpoch).toString();
    final name = (json['name'] ?? json['title'] ?? 'Tur').toString();
    final start = (json['start'] ?? json['start_label'] ?? 'Start').toString();
    final end = (json['end'] ?? json['end_label'] ?? 'Mål').toString();
    return Trip(id: id, name: name, startDate: DateTime.now(), endDate: DateTime.now(), start: start, end: end, status: TripStatus.planned);
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
