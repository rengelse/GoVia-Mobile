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
  List<PublishedRoute> publishedRoutes = const [];
  String? chatConversationId;
  bool chatLoading = false;

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
      try {
        await refreshChat();
      } catch (_) {
        // Chat is independent of the trip list. A chat failure must not blank the app.
      }
    } catch (e) {
      offline = true;
      error = 'Cloud-sync utilgjengelig. Viser lokal data der den finnes.';
    }
    notifyListeners();
  }


  Future<void> refreshPublishedRoutes({StageTransport? transport}) async {
    if (!auth.signedIn) return;
    try {
      final result = await api.domain('publishedRoute', 'listPublished', [transport?.name]);
      final raw = _unwrapList(result);
      publishedRoutes = raw.map(_publishedRouteFromLooseJson).toList(growable: false);
      notifyListeners();
    } catch (_) {
      // Community backend can be deployed independently from the mobile client.
      // Never replace the rest of the app state with an error just because Discover is unavailable.
    }
  }

  Future<PublishedRoute> publishStage({
    required Stage stage,
    required String title,
    required String description,
    List<String> tags = const [],
  }) async {
    if (!auth.signedIn) throw StateError('Du må være innlogget for å publisere.');
    RouteCandidate? official;
    for (final candidate in stage.routeCandidates) {
      if (candidate.id == stage.officialRouteId || (official == null && candidate.official)) official = candidate;
    }
    if (official == null && stage.transport != StageTransport.ferry) {
      throw StateError('Etappen mangler en offisiell rute.');
    }
    final payload = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'transport_mode': stage.transport.name,
      'start_label': stage.start,
      'end_label': stage.end,
      'distance_m': stage.distanceMeters,
      'duration_s': stage.durationSeconds,
      'geometry': [
        for (final point in official?.geometry ?? const <GeoPoint>[])
          [point.lon, point.lat],
      ],
      'tags': tags,
      'visibility': 'public',
      'status': 'published',
    };
    final result = await api.domain('publishedRoute', 'create', [payload]);
    final raw = result['data'] ?? result['result'];
    if (raw is! Map) throw StateError('Ugyldig svar ved publisering.');
    final route = _publishedRouteFromLooseJson(Map<String, dynamic>.from(raw));
    publishedRoutes = [route, ...publishedRoutes.where((item) => item.id != route.id)];
    notifyListeners();
    return route;
  }

  Future<void> setPublishedRouteFavorite(PublishedRoute route, bool saved) async {
    if (!auth.signedIn) throw StateError('Du må være innlogget.');
    await api.domain('publishedRoute', saved ? 'addFavorite' : 'removeFavorite', [route.id]);
    publishedRoutes = [
      for (final item in publishedRoutes)
        if (item.id == route.id)
          PublishedRoute(
            id: item.id,
            title: item.title,
            authorName: item.authorName,
            transport: item.transport,
            start: item.start,
            end: item.end,
            distanceMeters: item.distanceMeters,
            durationSeconds: item.durationSeconds,
            description: item.description,
            geometry: item.geometry,
            tags: item.tags,
            photoUrls: item.photoUrls,
            saved: saved,
          )
        else
          item,
    ];
    notifyListeners();
  }

  Future<void> selectTrip(Trip trip) async {
    activeTrip = trip;
    chatConversationId = null;
    messages = const [];
    await store.writeString('active_trip_id', trip.id);
    notifyListeners();
    if (auth.signedIn) {
      try { await refreshChat(); } catch (_) {}
    }
  }

  Future<void> addLocalTrip(Trip trip) async {
    trips = [trip, ...trips.where((t) => t.id != trip.id)];
    activeTrip = trip;
    notifyListeners();
  }


  Future<void> clonePublishedRoute(PublishedRoute route) async {
    final now = DateTime.now();
    final stage = Stage(
      id: 'community-${route.id}-${now.microsecondsSinceEpoch}',
      day: 0,
      order: 0,
      start: route.start,
      end: route.end,
      transport: route.transport,
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
      routeCandidates: [
        RouteCandidate(
          id: 'community-route-${route.id}',
          name: 'Publisert rute',
          distanceMeters: route.distanceMeters,
          durationSeconds: route.durationSeconds,
          geometry: route.geometry,
          official: true,
        ),
      ],
      officialRouteId: 'community-route-${route.id}',
    );
    final trip = Trip(
      id: 'community-trip-${route.id}-${now.microsecondsSinceEpoch}',
      name: route.title,
      startDate: now,
      endDate: now,
      start: route.start,
      end: route.end,
      status: TripStatus.planned,
      stages: [stage],
    );
    await addLocalTrip(trip);
  }

  Future<void> refreshChat() async {
    final trip = activeTrip;
    final user = auth.user;
    if (trip == null || user == null) {
      chatConversationId = null;
      messages = const [];
      notifyListeners();
      return;
    }
    chatLoading = true;
    notifyListeners();
    try {
      var conversationId = chatConversationId;
      if (conversationId == null || conversationId.isEmpty) {
        final ensured = await api.domain('chat', 'ensureTrip', [trip.id]);
        conversationId = _unwrapScalar(ensured)?.toString();
        if (conversationId == null || conversationId.isEmpty) throw StateError('Kunne ikke åpne tur-chat.');
        chatConversationId = conversationId;
      }
      final results = await Future.wait([
        api.domain('chat', 'listMessages', [
          {'conversationId': conversationId, 'tripId': trip.id, 'pageSize': 500}
        ]),
        api.domain('chat', 'listReactions', [
          {'conversationId': conversationId, 'tripId': trip.id}
        ]),
      ]);
      final rawMessages = _unwrapList(results[0]);
      final reactions = _unwrapList(results[1]);
      final reactionMap = <String, List<Map<String, dynamic>>>{};
      for (final reaction in reactions) {
        final messageId = (reaction['messageId'] ?? reaction['message_id'])?.toString() ?? '';
        if (messageId.isEmpty) continue;
        reactionMap.putIfAbsent(messageId, () => []).add(reaction);
      }
      messages = rawMessages.map((raw) {
        final id = raw['id']?.toString() ?? '';
        final senderId = (raw['senderId'] ?? raw['sender_id'])?.toString() ?? '';
        final mine = senderId == user.id;
        final participant = trip.participants.where((p) => p.id == senderId).firstOrNull;
        final messageReactions = reactionMap[id] ?? const [];
        final likes = messageReactions.where((item) => (item['reaction']?.toString() ?? 'like') == 'like').toList(growable: false);
        final createdAt = DateTime.tryParse((raw['createdAt'] ?? raw['created_at'])?.toString() ?? '') ?? DateTime.now();
        final editedAt = DateTime.tryParse((raw['editedAt'] ?? raw['edited_at'])?.toString() ?? '');
        final deletedAt = DateTime.tryParse((raw['deletedAt'] ?? raw['deleted_at'])?.toString() ?? '');
        return ChatMessage(
          id: id,
          sender: mine ? 'Du' : (participant?.name ?? 'Deltaker'),
          senderId: senderId,
          text: (raw['body'] ?? raw['text'])?.toString() ?? '',
          sentAt: createdAt,
          mine: mine,
          editedAt: editedAt,
          deletedAt: deletedAt,
          likeCount: likes.length,
          likedByMe: likes.any((item) => (item['userId'] ?? item['user_id'])?.toString() == user.id),
        );
      }).toList(growable: false);
    } finally {
      chatLoading = false;
      notifyListeners();
    }
  }

  Future<void> addMessage(String text) async {
    final clean = text.trim();
    final trip = activeTrip;
    final user = auth.user;
    if (clean.isEmpty || trip == null || user == null) return;
    if (chatConversationId == null) await refreshChat();
    final conversationId = chatConversationId;
    if (conversationId == null) throw StateError('Tur-chat er ikke tilgjengelig.');
    await api.domain('chat', 'createMessage', [
      {
        'id': 'mobile-${DateTime.now().microsecondsSinceEpoch}',
        'conversationId': conversationId,
        'tripId': trip.id,
        'senderId': user.id,
        'body': clean,
      }
    ]);
    await refreshChat();
  }

  Future<void> editMessage(ChatMessage message, String text) async {
    if (!message.mine || message.deleted) return;
    final clean = text.trim();
    if (clean.isEmpty) throw StateError('Meldingen kan ikke være tom.');
    await api.domain('chat', 'editMessage', [
      {'id': message.id, 'body': clean}
    ]);
    await refreshChat();
  }

  Future<void> deleteMessage(ChatMessage message) async {
    if (!message.mine || message.deleted) return;
    await api.domain('chat', 'deleteMessage', [
      {'id': message.id}
    ]);
    await refreshChat();
  }

  Future<void> toggleMessageLike(ChatMessage message) async {
    final user = auth.user;
    final trip = activeTrip;
    final conversationId = chatConversationId;
    if (user == null || trip == null || conversationId == null || message.deleted) return;
    if (message.likedByMe) {
      await api.domain('chat', 'removeReaction', [
        {'messageId': message.id, 'userId': user.id, 'reaction': 'like'}
      ]);
    } else {
      await api.domain('chat', 'addReaction', [
        {
          'messageId': message.id,
          'conversationId': conversationId,
          'tripId': trip.id,
          'userId': user.id,
          'reaction': 'like',
        }
      ]);
    }
    await refreshChat();
  }

  Future<void> uploadPublishedRoutePhoto({
    required PublishedRoute route,
    required Uint8List bytes,
    required String extension,
    required String contentType,
    String caption = '',
    double? lat,
    double? lon,
    int position = 0,
  }) async {
    final storagePath = await auth.uploadPublishedRoutePhoto(
      routeId: route.id,
      bytes: bytes,
      extension: extension,
      contentType: contentType,
    );
    try {
      await api.domain('publishedRoute', 'addPhoto', [
        {
          'routeId': route.id,
          'storagePath': storagePath,
          'caption': caption.trim(),
          'lat': lat,
          'lon': lon,
          'position': position,
        }
      ]);
    } catch (_) {
      try { await auth.removePublishedRoutePhoto(storagePath); } catch (_) {}
      rethrow;
    }
    await refreshPublishedRoutes();
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


  Object? _unwrapScalar(Map<String, dynamic> result) => result['data'] ?? result['result'];

  PublishedRoute _publishedRouteFromLooseJson(Map<String, dynamic> json) {
    final geometry = (json['geometry'] as List? ?? const [])
        .whereType<List>()
        .where((point) => point.length >= 2 && point[0] is num && point[1] is num)
        .map((point) => GeoPoint(lon: (point[0] as num).toDouble(), lat: (point[1] as num).toDouble()))
        .toList(growable: false);
    final profile = json['profiles'];
    final author = profile is Map ? (profile['display_name']?.toString() ?? 'GoVia-bruker') : 'GoVia-bruker';
    final photos = (json['published_route_photos'] as List? ?? const [])
        .whereType<Map>()
        .map((photo) => (photo['signed_url'] ?? photo['storage_path'])?.toString() ?? '')
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    final rawTransport = json['transport_mode']?.toString() ?? 'car';
    final transport = StageTransport.values.where((value) => value.name == rawTransport).firstOrNull ?? StageTransport.car;
    return PublishedRoute(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Rute',
      authorName: author,
      transport: transport,
      start: json['start_label']?.toString() ?? '',
      end: json['end_label']?.toString() ?? '',
      distanceMeters: (json['distance_m'] as num? ?? 0).round(),
      durationSeconds: (json['duration_s'] as num? ?? 0).round(),
      description: json['description']?.toString() ?? '',
      geometry: geometry,
      tags: (json['tags'] as List? ?? const []).map((value) => value.toString()).toList(growable: false),
      photoUrls: photos,
      saved: json['saved'] == true || ((json['published_route_favorites'] as List? ?? const []).isNotEmpty),
    );
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
