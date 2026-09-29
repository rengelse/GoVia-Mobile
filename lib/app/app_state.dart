import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  List<PublishedRoute> myPublishedRoutes = const [];
  UserProfile? profile;
  bool profileLoading = false;
  String androidAutoThemeMode = 'system';
  String? chatConversationId;
  bool chatLoading = false;

  static const MethodChannel _carChannel = MethodChannel('no.govia.mobile/car');
  bool _carSyncQueued = false;
  String? _lastAndroidAutoStateJson;

  bool get signedIn => auth.signedIn || (AppConfig.devSeed && !auth.configured);

  void _scheduleAndroidAutoSync() {
    if (loading || _carSyncQueued) return;
    _carSyncQueued = true;
    scheduleMicrotask(() async {
      try {
        await _syncAndroidAutoState();
      } finally {
        _carSyncQueued = false;
      }
    });
  }

  Future<void> _importAndroidAutoRecordings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final raw = await _carChannel.invokeMethod<String>('drainRecordedRides');
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) return;
      final imported = <Trip>[];
      for (final item in decoded.whereType<Map>()) {
        final row = Map<String, dynamic>.from(item);
        final rawPoints = row['points'];
        if (rawPoints is! List || rawPoints.length < 2) continue;
        final geometry = rawPoints.whereType<List>().where((p) => p.length >= 2).map((p) {
          final lon = p[0]; final lat = p[1];
          if (lon is! num || lat is! num) return null;
          return GeoPoint(lon: lon.toDouble(), lat: lat.toDouble());
        }).whereType<GeoPoint>().toList(growable: false);
        if (geometry.length < 2) continue;
        final startedAt = DateTime.fromMillisecondsSinceEpoch((row['startedAt'] as num? ?? DateTime.now().millisecondsSinceEpoch).round());
        final endedAt = DateTime.fromMillisecondsSinceEpoch((row['endedAt'] as num? ?? startedAt.millisecondsSinceEpoch).round());
        var distance = 0.0;
        for (var i = 1; i < geometry.length; i++) {
          distance += _distanceMeters(geometry[i - 1], geometry[i]);
        }
        final id = row['id']?.toString() ?? 'car-recording-${startedAt.microsecondsSinceEpoch}';
        final routeId = '$id-route';
        final durationSeconds = endedAt.difference(startedAt).inSeconds.clamp(0, 7 * 24 * 3600).toInt();
        final stage = Stage(
          id: '$id-stage', day: 0, order: 0,
          start: 'Opptak start', end: 'Opptak slutt',
          transport: profile?.preferredTransport ?? StageTransport.motorcycle,
          distanceMeters: distance.round(),
          durationSeconds: durationSeconds,
          routeCandidates: [RouteCandidate(id: routeId, name: 'Opptatt rute', distanceMeters: distance.round(), durationSeconds: durationSeconds, geometry: geometry, official: true)],
          officialRouteId: routeId,
        );
        imported.add(Trip(
          id: id,
          name: 'Opptatt tur ${startedAt.day.toString().padLeft(2, '0')}.${startedAt.month.toString().padLeft(2, '0')}.${startedAt.year}',
          startDate: startedAt,
          endDate: endedAt,
          start: stage.start,
          end: stage.end,
          status: TripStatus.completed,
          stages: [stage],
        ));
      }
      if (imported.isEmpty) return;
      for (final trip in imported) {
        trips = [trip, ...trips.where((existing) => existing.id != trip.id)];
        final snapshots = store.readJson('completed_trip_snapshots') ?? <String, dynamic>{};
        snapshots[trip.id] = _tripToSnapshot(trip);
        await store.writeJson('completed_trip_snapshots', snapshots);
      }
    } on MissingPluginException {
      // Android Auto bridge is unavailable on non-Android/test hosts.
    } catch (_) {
      // Never block app startup because of a malformed vehicle recording.
    }
  }

  double _distanceMeters(GeoPoint a, GeoPoint b) {
    const radius = 6371000.0;
    final p1 = a.lat * math.pi / 180;
    final p2 = b.lat * math.pi / 180;
    final dp = (b.lat - a.lat) * math.pi / 180;
    final dl = (b.lon - a.lon) * math.pi / 180;
    final h = math.sin(dp / 2) * math.sin(dp / 2) + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * radius * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  Future<void> setAndroidAutoThemeMode(String mode) async {
    if (!const {'system', 'light', 'dark'}.contains(mode)) return;
    androidAutoThemeMode = mode;
    await store.writeString('android_auto_theme_mode', mode);
    notifyListeners();
    _scheduleAndroidAutoSync();
  }

  Future<void> _syncAndroidAutoState() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || loading) return;
    try {
      final accessToken = await auth.accessToken();
      final payload = <String, dynamic>{
        'version': 3,
        'apiBaseUrl': AppConfig.apiBaseUrl,
        if (accessToken != null && accessToken.isNotEmpty) 'accessToken': accessToken,
        'activeTripId': activeTrip?.id,
        'voiceEnabled': profile?.voiceEnabled ?? true,
        'themeMode': androidAutoThemeMode,
        'trips': trips.map(_tripToCarJson).toList(growable: false),
        'pois': pois.map((poi) => {
          'id': poi.id,
          'name': poi.name,
          'category': poi.category,
          'distanceMeters': poi.distanceMeters,
        }).toList(growable: false),
      };
      final encoded = jsonEncode(payload);
      if (encoded == _lastAndroidAutoStateJson) return;
      await _carChannel.invokeMethod<void>('syncState', encoded);
      _lastAndroidAutoStateJson = encoded;
    } on MissingPluginException {
      // Android Auto bridge is Android-only and intentionally optional elsewhere.
    } catch (_) {
      // Car display sync must never block normal mobile operation.
    }
  }

  Map<String, dynamic> _tripToCarJson(Trip trip) => {
    'id': trip.id,
    'name': trip.name,
    'start': trip.start,
    'end': trip.end,
    'startDate': trip.startDate.toIso8601String(),
    'endDate': trip.endDate.toIso8601String(),
    'status': trip.status.name,
    'stages': trip.stages.map((stage) {
      final official = stage.routeCandidates.where((route) => route.id == stage.officialRouteId).firstOrNull
          ?? stage.routeCandidates.where((route) => route.official).firstOrNull
          ?? stage.routeCandidates.firstOrNull;
      return <String, dynamic>{
        'id': stage.id,
        'day': stage.day,
        'order': stage.order,
        'name': stage.name,
        'status': stage.status.name,
        'routeId': official?.id ?? stage.officialRouteId ?? stage.id,
        'start': stage.start,
        'end': stage.end,
        'transport': stage.transport.name,
        'waypoints': stage.waypoints.map((item) => item.toJson()).toList(growable: false),
        'distanceMeters': official?.distanceMeters ?? stage.distanceMeters,
        'durationSeconds': official?.durationSeconds ?? stage.durationSeconds,
        'routeProfile': stage.routeProfile,
        'routePreferences': stage.routePreferences.toJson(),
        'geometry': [for (final point in official?.geometry ?? const <GeoPoint>[]) [point.lon, point.lat]],
        'maneuvers': [
          for (final maneuver in official?.maneuvers ?? const <NavigationManeuver>[]) maneuver.toJson()
        ],
      };
    }).toList(growable: false),
  };

  Future<void> initialize() async {
    loading = true;
    androidAutoThemeMode = store.readString('android_auto_theme_mode') ?? 'system';
    if (!const {'system', 'light', 'dark'}.contains(androidAutoThemeMode)) androidAutoThemeMode = 'system';
    notifyListeners();
    try {
      trips = _mergeLocalTripSnapshots(trips);
      final storedActiveId = store.readString('active_trip_id');
      activeTrip = trips.where((trip) => trip.id == storedActiveId && _canBeActiveTrip(trip)).firstOrNull;
      if (AppConfig.devSeed) _loadDevSeed();
      if (auth.signedIn) await refreshCloud();
      await _importAndroidAutoRecordings();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
      _scheduleAndroidAutoSync();
    }
  }

  void setShellIndex(int index) {
    shellIndex = index;
    notifyListeners();
  }

  Future<void> refreshCloud() async {
    if (!auth.signedIn) return;
    try {
      await _flushPendingTripStatusUpdates();
      try { await refreshProfile(notify: false); } catch (_) {}
      final result = await api.domain('trip', 'list', const []);
      final raw = _unwrapList(result);
      final cloudTrips = await Future.wait(raw.map((row) async {
        final base = _tripFromLooseJson(row);
        try {
          final stageResult = await api.domain('stage', 'listForTrip', [base.id]);
          final stages = _unwrapList(stageResult).map(_stageFromLooseJson).toList(growable: false)
            ..sort((a, b) => a.day != b.day ? a.day.compareTo(b.day) : a.order.compareTo(b.order));
          return _copyTrip(base, stages: stages);
        } catch (_) {
          return base;
        }
      }));
      trips = _mergeLocalTripSnapshots(_mergeCompletedSnapshots(cloudTrips));
      final storedActiveId = store.readString('active_trip_id');
      activeTrip = trips.where((trip) => trip.id == storedActiveId && _canBeActiveTrip(trip)).firstOrNull
          ?? trips.where((trip) => trip.status == TripStatus.active).firstOrNull
          ?? trips.where((trip) => trip.status == TripStatus.planned).firstOrNull;
      offline = false;
      error = null;
      try {
        await refreshChat();
      } catch (_) {
        // Chat is independent of trip hydration.
      }
    } catch (_) {
      offline = true;
      trips = _mergeLocalTripSnapshots(_mergeCompletedSnapshots(trips));
      error = 'Cloud-sync utilgjengelig. Viser lokal data der den finnes.';
    }
    notifyListeners();
    _scheduleAndroidAutoSync();
  }


  Future<Trip> redeemDesktopHandoff(String rawCode) async {
    if (!auth.signedIn) {
      throw StateError('Du må være innlogget for å hente en tur fra Desktop.');
    }
    final code = rawCode.trim();
    if (code.isEmpty) {
      throw StateError('QR-koden er tom.');
    }
    String token = code;
    final uri = Uri.tryParse(code);
    if (uri != null && uri.scheme == 'govia' && uri.host == 'trip-handoff') {
      token = uri.queryParameters['token']?.trim() ?? '';
    }
    if (token.length < 20) {
      throw StateError('QR-koden er ikke en gyldig GoVia-turkode.');
    }

    final response = await api.domain('mobileHandoff', 'redeem', [token]);
    final payload = _unwrapScalar(response);
    if (payload is! Map) {
      throw StateError('GoVia returnerte ikke et gyldig handoff-svar.');
    }
    final data = Map<String, dynamic>.from(payload);
    final snapshotRaw = data['snapshot'];
    if (snapshotRaw is! Map) {
      throw StateError('Tur-snapshot mangler i svaret.');
    }
    final snapshot = Map<String, dynamic>.from(snapshotRaw);
    final tripRaw = snapshot['trip'];
    if (tripRaw is! Map) {
      throw StateError('Turen mangler i snapshotet.');
    }
    final base = _tripFromLooseJson(Map<String, dynamic>.from(tripRaw));
    final nestedTripStages = tripRaw['stages'];
    final stageSource = snapshot['stages'] is List ? snapshot['stages'] : nestedTripStages;
    final stageRows = (stageSource as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    for (final row in stageRows) {
      final rowTripId = (row['trip_id'] ?? row['tripId'])?.toString();
      if (rowTripId != null && rowTripId.isNotEmpty && rowTripId != base.id) {
        throw StateError('Turintegritet brutt: snapshotet inneholder etappe fra en annen tur.');
      }
    }
    final stages = stageRows.map(_stageFromLooseJson).toList(growable: false)
      ..sort((a, b) => a.day != b.day ? a.day.compareTo(b.day) : a.order.compareTo(b.order));
    final imported = _copyTrip(base, stages: stages);
    trips = [imported, ...trips.where((trip) => trip.id != imported.id)];
    activeTrip = imported;
    chatConversationId = null;
    messages = const [];
    await store.writeString('active_trip_id', imported.id);
    offline = false;
    error = null;
    notifyListeners();
    _scheduleAndroidAutoSync();
    try { await refreshChat(); } catch (_) {}
    return imported;
  }

  Future<void> refreshProfile({bool notify = true}) async {
    final user = auth.user;
    if (user == null) return;
    profileLoading = true;
    if (notify) notifyListeners();
    try {
      final result = await api.domain('profile', 'getById', [user.id]);
      final raw = _unwrapScalar(result);
      if (raw is Map) {
        profile = _profileFromLooseJson(Map<String, dynamic>.from(raw), fallbackEmail: user.email ?? '');
        await store.writeJson('profile_cache', _profileToJson(profile!));
      }
    } catch (_) {
      final cached = store.readJson('profile_cache');
      if (cached != null) profile = _profileFromLooseJson(cached, fallbackEmail: user.email ?? '');
      rethrow;
    } finally {
      profileLoading = false;
      if (notify) notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? location,
    String? avatarUrl,
    StageTransport? preferredTransport,
    String? unitSystem,
    bool? voiceEnabled,
    String? locationSharing,
    bool? profilePublic,
    bool? showPublishedRoutes,
    bool? allowRouteRatings,
  }) async {
    final user = auth.user;
    if (user == null) throw StateError('Du må være innlogget.');
    final patch = <String, dynamic>{
      if (displayName != null) 'display_name': displayName.trim(),
      if (bio != null) 'bio': bio.trim(),
      if (location != null) 'location': location.trim(),
      if (avatarUrl != null) 'avatar_data': avatarUrl,
      if (preferredTransport != null) 'preferred_transport_mode': preferredTransport.name,
      if (unitSystem != null) 'unit_system': unitSystem,
      if (voiceEnabled != null) 'voice_enabled': voiceEnabled,
      if (locationSharing != null) 'location_sharing': locationSharing,
      if (profilePublic != null) 'profile_public': profilePublic,
      if (showPublishedRoutes != null) 'show_published_routes': showPublishedRoutes,
      if (allowRouteRatings != null) 'allow_route_ratings': allowRouteRatings,
    };
    if (patch.isEmpty) return;
    final result = await api.domain('profile', 'update', [user.id, patch]);
    final raw = _unwrapScalar(result);
    if (raw is! Map) throw StateError('GoVia bekreftet ikke profiloppdateringen.');
    profile = _profileFromLooseJson(Map<String, dynamic>.from(raw), fallbackEmail: user.email ?? '');
    await store.writeJson('profile_cache', _profileToJson(profile!));
    notifyListeners();
    if (voiceEnabled != null) _scheduleAndroidAutoSync();
  }

  Future<void> uploadProfileAvatar({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final url = await auth.uploadProfileAvatar(bytes: bytes, extension: extension, contentType: contentType);
    await updateProfile(avatarUrl: url);
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
    String visibility = 'public',
    String status = 'published',
    String? sourceTripId,
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
      'source_trip_id': sourceTripId,
      'source_stage_id': stage.id,
      'visibility': visibility,
      'status': status,
    };
    final result = await api.domain('publishedRoute', 'create', [payload]);
    final raw = result['data'] ?? result['result'];
    if (raw is! Map) throw StateError('Ugyldig svar ved publisering.');
    final route = _publishedRouteFromLooseJson(Map<String, dynamic>.from(raw));
    publishedRoutes = [route, ...publishedRoutes.where((item) => item.id != route.id)];
    myPublishedRoutes = [route, ...myPublishedRoutes.where((item) => item.id != route.id)];
    notifyListeners();
    return route;
  }

  Future<void> refreshMyPublishedRoutes() async {
    if (!auth.signedIn) return;
    final result = await api.domain('publishedRoute', 'listMine', const []);
    myPublishedRoutes = _unwrapList(result).map(_publishedRouteFromLooseJson).toList(growable: false);
    notifyListeners();
  }

  Future<PublishedRoute> updatePublishedRoute({
    required PublishedRoute route,
    required String title,
    required String description,
    required List<String> tags,
    required String visibility,
    String? status,
  }) async {
    final payload = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'transport_mode': route.transport.name,
      'start_label': route.start,
      'end_label': route.end,
      'distance_m': route.distanceMeters,
      'duration_s': route.durationSeconds,
      'geometry': [for (final point in route.geometry) [point.lon, point.lat]],
      'tags': tags,
      'source_trip_id': route.sourceTripId,
      'source_stage_id': route.sourceStageId,
      'visibility': visibility,
      'status': status ?? route.status,
    };
    final result = await api.domain('publishedRoute', 'update', [route.id, payload]);
    final raw = _unwrapScalar(result);
    if (raw is! Map) throw StateError('Ugyldig svar ved oppdatering.');
    final updated = _publishedRouteFromLooseJson(Map<String, dynamic>.from(raw));
    publishedRoutes = [for (final item in publishedRoutes) if (item.id == updated.id) updated else item];
    myPublishedRoutes = [for (final item in myPublishedRoutes) if (item.id == updated.id) updated else item, if (!myPublishedRoutes.any((item) => item.id == updated.id)) updated];
    notifyListeners();
    return updated;
  }

  Future<void> archivePublishedRoute(PublishedRoute route) async {
    await api.domain('publishedRoute', 'archive', [route.id]);
    await refreshMyPublishedRoutes();
    await refreshPublishedRoutes();
  }

  Future<void> deletePublishedRoute(PublishedRoute route) async {
    await api.domain('publishedRoute', 'delete', [route.id]);
    myPublishedRoutes = myPublishedRoutes.where((item) => item.id != route.id).toList(growable: false);
    publishedRoutes = publishedRoutes.where((item) => item.id != route.id).toList(growable: false);
    notifyListeners();
  }

  Future<void> setPublishedRouteCover(PublishedRoute route, PublishedRoutePhoto photo) async {
    await api.domain('publishedRoute', 'setCoverPhoto', [route.id, photo.id]);
    await refreshMyPublishedRoutes();
    await refreshPublishedRouteDetail(route.id);
  }

  Future<void> removePublishedRoutePhoto(PublishedRoute route, PublishedRoutePhoto photo) async {
    await api.domain('publishedRoute', 'removePhoto', [photo.id]);
    await refreshMyPublishedRoutes();
    await refreshPublishedRouteDetail(route.id);
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
            photos: item.photos,
            saved: saved,
            ratingCount: item.ratingCount,
            rating: item.rating,
            myRating: item.myRating,
            allowRatings: item.allowRatings,
            authorId: item.authorId,
            visibility: item.visibility,
            status: item.status,
            sourceTripId: item.sourceTripId,
            sourceStageId: item.sourceStageId,
          )
        else
          item,
    ];
    notifyListeners();
  }


  Future<PublishedRoute> refreshPublishedRouteDetail(String routeId) async {
    final result = await api.domain('publishedRoute', 'getById', [routeId]);
    final raw = _unwrapScalar(result);
    if (raw is! Map) throw StateError('Fant ikke den publiserte ruten.');
    final route = _publishedRouteFromLooseJson(Map<String, dynamic>.from(raw));
    publishedRoutes = [
      for (final item in publishedRoutes) if (item.id == route.id) route else item,
      if (!publishedRoutes.any((item) => item.id == route.id)) route,
    ];
    notifyListeners();
    return route;
  }

  Future<PublishedRoute> setPublishedRouteRating(
    PublishedRoute route, {
    required int experience,
    required int scenery,
    required int surface,
  }) async {
    await api.domain('publishedRoute', 'setRating', [route.id, {
      'experience': experience,
      'scenery': scenery,
      'surface': surface,
    }]);
    return refreshPublishedRouteDetail(route.id);
  }

  Future<ElevationProfile> loadElevationProfile(PublishedRoute route) async {
    if (route.geometry.length < 2) throw StateError('Ruten mangler geometri for høydeprofil.');
    final result = await api.postJson('/api/v1/map/elevation-profile', {
      'geometry': [for (final point in route.geometry) [point.lon, point.lat]],
    });
    final raw = _unwrapScalar(result);
    if (raw is! Map) throw StateError('Kunne ikke hente høydeprofil.');
    final json = Map<String, dynamic>.from(raw);
    final samples = (json['samples'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ElevationSample(
              distanceMeters: (item['distanceMeters'] as num? ?? 0).round(),
              elevationMeters: (item['elevationMeters'] as num? ?? 0).round(),
            ))
        .toList(growable: false);
    if (samples.length < 2) throw StateError('Høydeprofilen mangler datapunkter.');
    return ElevationProfile(
      samples: samples,
      ascentMeters: (json['ascentMeters'] as num? ?? 0).round(),
      descentMeters: (json['descentMeters'] as num? ?? 0).round(),
      minElevationMeters: (json['minElevationMeters'] as num? ?? 0).round(),
      maxElevationMeters: (json['maxElevationMeters'] as num? ?? 0).round(),
      source: json['source']?.toString() ?? '',
    );
  }

  Future<void> selectTrip(Trip trip) async {
    activeTrip = trip;
    chatConversationId = null;
    messages = const [];
    await store.writeString('active_trip_id', trip.id);
    notifyListeners();
    _scheduleAndroidAutoSync();
    if (auth.signedIn) {
      try { await refreshChat(); } catch (_) {}
    }
  }

  Future<void> startNavigationStage(Stage stage, {RouteCandidate? navigationRoute}) async {
    Trip? trip;
    final current = activeTrip;
    if (current != null && current.stages.any((item) => item.id == stage.id)) {
      trip = current;
    } else {
      for (final candidate in trips) {
        if (candidate.stages.any((item) => item.id == stage.id)) {
          trip = candidate;
          break;
        }
      }
    }
    if (trip == null) return;

    final updatedStages = [
      for (final item in trip.stages)
        if (item.id == stage.id)
          _stageWithNavigationRoute(item, navigationRoute).copyWith(status: StageStatus.active)
        else if (item.status == StageStatus.active)
          item.copyWith(status: StageStatus.planned)
        else
          item,
    ];
    final active = _copyTrip(trip, status: TripStatus.active, stages: updatedStages);
    trips = [active, ...trips.where((item) => item.id != active.id)];
    activeTrip = active;
    await store.writeString('active_trip_id', active.id);
    await store.writeString('active_stage_id_${active.id}', stage.id);
    await _persistLocalTripSnapshot(active);

    if (auth.signedIn && active.ownerId.isNotEmpty && active.ownerId == auth.user?.id) {
      final pending = store.readJson('pending_trip_status_updates') ?? <String, dynamic>{};
      pending[active.id] = {
        'status': 'Aktiv',
        'startedAt': DateTime.now().toIso8601String(),
      };
      await store.writeJson('pending_trip_status_updates', pending);
      try { await _flushPendingTripStatusUpdates(); } catch (_) {}
    }
    notifyListeners();
    _scheduleAndroidAutoSync();
  }

  Stage _stageWithNavigationRoute(Stage stage, RouteCandidate? route, {List<StageWaypoint>? waypoints}) {
    if (route == null) return stage;
    final routes = <RouteCandidate>[
      route.copyWith(official: true),
      ...stage.routeCandidates.where((candidate) => candidate.id != route.id).map((candidate) => candidate.copyWith(official: false)),
    ];
    return stage.copyWith(
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
      routeCandidates: routes,
      officialRouteId: route.id,
      waypoints: waypoints ?? stage.waypoints,
    );
  }

  Future<void> updateNavigationStageRoute(String stageId, RouteCandidate route, {List<StageWaypoint>? waypoints}) async {
    Trip? owner;
    for (final candidate in trips) {
      if (candidate.stages.any((stage) => stage.id == stageId)) {
        owner = candidate;
        break;
      }
    }
    if (owner == null) return;
    final updated = _copyTrip(
      owner,
      stages: [
        for (final stage in owner.stages)
          if (stage.id == stageId) _stageWithNavigationRoute(stage, route, waypoints: waypoints) else stage,
      ],
    );
    trips = [updated, ...trips.where((trip) => trip.id != updated.id)];
    if (activeTrip?.id == updated.id) activeTrip = updated;
    await _persistLocalTripSnapshot(updated);
    notifyListeners();
    _scheduleAndroidAutoSync();
  }

  String? activeStageIdForTrip(String tripId) => store.readString('active_stage_id_$tripId');

  static const _phoneNavigationRuntimeKey = 'phone_navigation_runtime_v2';

  Future<void> persistPhoneNavigationRuntime({
    required String tripId,
    required String stageId,
    required String routeId,
    required Map<String, dynamic> snapshot,
  }) =>
      store.writeJson(_phoneNavigationRuntimeKey, {
        'tripId': tripId,
        'stageId': stageId,
        'routeId': routeId,
        'snapshot': snapshot,
      });

  Map<String, dynamic>? phoneNavigationRuntime({
    required String tripId,
    required String stageId,
    required String routeId,
  }) {
    final value = store.readJson(_phoneNavigationRuntimeKey);
    if (value == null ||
        value['tripId']?.toString() != tripId ||
        value['stageId']?.toString() != stageId ||
        value['routeId']?.toString() != routeId ||
        value['snapshot'] is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(value['snapshot'] as Map);
  }

  Future<void> clearPhoneNavigationRuntime() => store.remove(_phoneNavigationRuntimeKey);


  Stage? nextStageAfter(Trip trip, Stage stage) {
    final ordered = [...trip.stages]..sort((a, b) {
      final day = a.day.compareTo(b.day);
      return day != 0 ? day : a.order.compareTo(b.order);
    });
    final index = ordered.indexWhere((item) => item.id == stage.id);
    if (index < 0) return null;
    for (var i = index + 1; i < ordered.length; i++) {
      if (ordered[i].status != StageStatus.completed) return ordered[i];
    }
    return null;
  }

  Future<void> deleteOwnTrip(Trip trip) async {
    final user = auth.user;
    if (user == null) {
      throw StateError('Du må være innlogget for å slette en tur.');
    }
    if (trip.ownerId.isNotEmpty && trip.ownerId != user.id) {
      throw StateError('Bare tureier kan slette denne turen.');
    }
    if (trip.ownerId.isNotEmpty) {
      await api.domain('trip', 'delete', [
        {'id': trip.id, 'ownerId': user.id},
      ]);
    }

    trips = trips.where((item) => item.id != trip.id).toList(growable: false);
    if (activeTrip?.id == trip.id) {
      activeTrip = null;
      chatConversationId = null;
      messages = const [];
      await store.remove('active_trip_id');
      await store.remove('active_stage_id_${trip.id}');
    }

    final completedIds = store.readJson('completed_trip_ids') ?? <String, dynamic>{};
    if (completedIds.remove(trip.id) != null) {
      await store.writeJson('completed_trip_ids', completedIds);
    }
    final snapshots = store.readJson('completed_trip_snapshots') ?? <String, dynamic>{};
    if (snapshots.remove(trip.id) != null) {
      await store.writeJson('completed_trip_snapshots', snapshots);
    }
    final pending = store.readJson('pending_trip_status_updates') ?? <String, dynamic>{};
    if (pending.remove(trip.id) != null) {
      await store.writeJson('pending_trip_status_updates', pending);
    }
    await _removeLocalTripSnapshot(trip.id);
    notifyListeners();
    _scheduleAndroidAutoSync();
  }

  Future<void> addLocalTrip(Trip trip) async {
    trips = [trip, ...trips.where((t) => t.id != trip.id)];
    activeTrip = trip;
    await _persistLocalTripSnapshot(trip);
    await store.writeString('active_trip_id', trip.id);
    notifyListeners();
    _scheduleAndroidAutoSync();
  }

  Future<bool> completeNavigationStage(Stage stage) async {
    final trip = activeTrip;
    if (trip == null) return false;
    final updatedStages = [
      for (final item in trip.stages)
        if (item.id == stage.id) item.copyWith(status: StageStatus.completed) else item,
    ];

    final allStagesCompleted = updatedStages.isNotEmpty && updatedStages.every((item) => item.status == StageStatus.completed);
    if (!allStagesCompleted) {
      final updated = _copyTrip(trip, status: TripStatus.active, stages: updatedStages);
      trips = [updated, ...trips.where((item) => item.id != trip.id)];
      activeTrip = updated;
      await store.remove('active_stage_id_${trip.id}');
      await _persistLocalTripSnapshot(updated);
      notifyListeners();
      _scheduleAndroidAutoSync();
      return false;
    }

    final completedAt = DateTime.now();
    final completed = _copyTrip(trip, status: TripStatus.completed, endDate: completedAt, stages: updatedStages);
    trips = [completed, ...trips.where((item) => item.id != trip.id)];
    activeTrip = null;
    await _persistLocalTripSnapshot(completed);
    await store.remove('active_trip_id');
    await store.remove('active_stage_id_${trip.id}');
    final completedIds = store.readJson('completed_trip_ids') ?? <String, dynamic>{};
    completedIds[trip.id] = completedAt.toIso8601String();
    await store.writeJson('completed_trip_ids', completedIds);
    final snapshots = store.readJson('completed_trip_snapshots') ?? <String, dynamic>{};
    snapshots[trip.id] = _tripToSnapshot(completed);
    await store.writeJson('completed_trip_snapshots', snapshots);
    if (auth.signedIn) {
      final pending = store.readJson('pending_trip_status_updates') ?? <String, dynamic>{};
      pending[trip.id] = {'status': 'Fullført', 'completedAt': completedAt.toIso8601String()};
      await store.writeJson('pending_trip_status_updates', pending);
      try { await _flushPendingTripStatusUpdates(); } catch (_) {}
    }
    notifyListeners();
    _scheduleAndroidAutoSync();
    return true;
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

  Future<PublishedRoutePhoto> uploadPublishedRoutePhoto({
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
      final result = await api.domain('publishedRoute', 'addPhoto', [
        {
          'routeId': route.id,
          'storagePath': storagePath,
          'caption': caption.trim(),
          'lat': lat,
          'lon': lon,
          'position': position,
        }
      ]);
      final raw = _unwrapScalar(result);
      if (raw is! Map) throw StateError('Ugyldig svar ved bildeopplasting.');
      final photo = _publishedRoutePhotoFromLooseJson(Map<String, dynamic>.from(raw));
      await refreshPublishedRoutes();
      return photo;
    } catch (_) {
      try { await auth.removePublishedRoutePhoto(storagePath); } catch (_) {}
      rethrow;
    }
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

  PublishedRoutePhoto _publishedRoutePhotoFromLooseJson(Map<String, dynamic> photo) => PublishedRoutePhoto(
        id: photo['id']?.toString() ?? '',
        url: (photo['signed_url'] ?? photo['storage_path'])?.toString() ?? '',
        caption: photo['caption']?.toString() ?? '',
        lat: (photo['lat'] as num?)?.toDouble(),
        lon: (photo['lon'] as num?)?.toDouble(),
        position: (photo['position'] as num? ?? 0).round(),
      );

  PublishedRoute _publishedRouteFromLooseJson(Map<String, dynamic> json) {
    final geometry = (json['geometry'] as List? ?? const [])
        .whereType<List>()
        .where((point) => point.length >= 2 && point[0] is num && point[1] is num)
        .map((point) => GeoPoint(lon: (point[0] as num).toDouble(), lat: (point[1] as num).toDouble()))
        .toList(growable: false);
    final profile = json['profiles'];
    final author = profile is Map ? (profile['display_name']?.toString() ?? 'GoVia-bruker') : 'GoVia-bruker';
    RouteRating? parseRating(Object? raw) {
      if (raw is! Map) return null;
      double number(Object? value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
      return RouteRating(
        experience: number(raw['experience']),
        scenery: number(raw['scenery']),
        surface: number(raw['surface']),
      );
    }
    final ratingSummary = json['rating_summary'];
    final photos = (json['published_route_photos'] as List? ?? const [])
        .whereType<Map>()
        .map((photo) => _publishedRoutePhotoFromLooseJson(Map<String, dynamic>.from(photo)))
        .where((photo) => photo.url.isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => a.position.compareTo(b.position));
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
      photos: photos,
      saved: json['saved'] == true || ((json['published_route_favorites'] as List? ?? const []).isNotEmpty),
      ratingCount: ratingSummary is Map ? (ratingSummary['count'] as num? ?? 0).round() : 0,
      rating: parseRating(ratingSummary),
      myRating: parseRating(json['my_rating']),
      allowRatings: profile is Map ? profile['allow_route_ratings'] != false : true,
      authorId: json['author_id']?.toString() ?? '',
      visibility: json['visibility']?.toString() ?? 'public',
      status: json['status']?.toString() ?? 'published',
      sourceTripId: json['source_trip_id']?.toString(),
      sourceStageId: json['source_stage_id']?.toString(),
    );
  }

  UserProfile _profileFromLooseJson(Map<String, dynamic> json, {required String fallbackEmail}) {
    final rawTransport = (json['preferred_transport_mode'] ?? json['preferredTransportMode'] ?? 'motorcycle').toString();
    final preferred = StageTransport.values.where((value) => value.name == rawTransport).firstOrNull ?? StageTransport.motorcycle;
    return UserProfile(
      id: (json['id'] ?? auth.user?.id ?? '').toString(),
      email: (json['email'] ?? fallbackEmail).toString(),
      displayName: (json['display_name'] ?? json['displayName'] ?? '').toString(),
      bio: (json['bio'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      avatarUrl: (json['avatar_data'] ?? json['avatarUrl'])?.toString(),
      preferredTransport: preferred,
      unitSystem: (json['unit_system'] ?? json['unitSystem'] ?? 'metric').toString(),
      voiceEnabled: json['voice_enabled'] != false && json['voiceEnabled'] != false,
      locationSharing: (json['location_sharing'] ?? json['locationSharing'] ?? 'active_trip').toString(),
      profilePublic: json['profile_public'] != false && json['profilePublic'] != false,
      showPublishedRoutes: json['show_published_routes'] != false && json['showPublishedRoutes'] != false,
      allowRouteRatings: json['allow_route_ratings'] != false && json['allowRouteRatings'] != false,
    );
  }

  Map<String, dynamic> _profileToJson(UserProfile value) => {
        'id': value.id,
        'email': value.email,
        'display_name': value.displayName,
        'bio': value.bio,
        'location': value.location,
        'avatar_data': value.avatarUrl,
        'preferred_transport_mode': value.preferredTransport.name,
        'unit_system': value.unitSystem,
        'voice_enabled': value.voiceEnabled,
        'location_sharing': value.locationSharing,
        'profile_public': value.profilePublic,
        'show_published_routes': value.showPublishedRoutes,
        'allow_route_ratings': value.allowRouteRatings,
      };

  Trip _tripFromLooseJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['trip_id'] ?? DateTime.now().microsecondsSinceEpoch).toString();
    final name = (json['name'] ?? json['title'] ?? 'Tur').toString();
    final start = (json['startLabel'] ?? json['start_label'] ?? json['start'] ?? 'Start').toString();
    final end = (json['destinationLabel'] ?? json['destination_label'] ?? json['destination'] ?? json['end_label'] ?? json['end'] ?? 'Mål').toString();
    final rawStatus = (json['status'] ?? '').toString().trim().toLowerCase();
    final locallyCompleted = (store.readJson('completed_trip_ids') ?? const <String, dynamic>{}).containsKey(id);
    final status = locallyCompleted
        ? TripStatus.completed
        : switch (rawStatus) {
            'active' || 'aktiv' => TripStatus.active,
            'completed' || 'complete' || 'fullført' || 'fullfort' => TripStatus.completed,
            'archived' || 'arkivert' => TripStatus.archived,
            _ => TripStatus.planned,
          };
    final startDate = _parseDate(json['startDate'] ?? json['start_date'] ?? json['createdAt'] ?? json['created_at']) ?? DateTime.now();
    var endDate = _parseDate(json['endDate'] ?? json['end_date'] ?? json['updatedAt'] ?? json['updated_at']) ?? startDate;
    if (locallyCompleted) {
      final completedAt = (store.readJson('completed_trip_ids') ?? const <String, dynamic>{})[id];
      endDate = _parseDate(completedAt) ?? endDate;
    }
    return Trip(id: id, name: name, startDate: startDate, endDate: endDate, start: start, end: end, status: status, ownerId: (json['ownerId'] ?? json['owner_id'] ?? '').toString());
  }

  StageStatus _stageStatusFromLooseValue(dynamic value) => switch (value?.toString().trim().toLowerCase()) {
        'active' || 'aktiv' => StageStatus.active,
        'completed' || 'complete' || 'fullført' || 'fullfort' => StageStatus.completed,
        _ => StageStatus.planned,
      };

  StageWaypointKind _waypointKindFromLooseValue(dynamic value, StageWaypointKind fallback) => switch (value?.toString().trim().toLowerCase()) {
        'via' || 'via_point' || 'viapoint' => StageWaypointKind.via,
        'stop' || 'stopp' => StageWaypointKind.stop,
        'poi' || 'point_of_interest' => StageWaypointKind.poi,
        _ => fallback,
      };

  StageWaypoint? _stageWaypointFromLooseJson(Map<String, dynamic> row, StageWaypointKind fallback, int index) {
    final location = _geoPointFromLooseValue(row['location'] ?? row['point'] ?? row['coordinates'] ?? row);
    final name = (row['name'] ?? row['label'] ?? row['title'] ?? '').toString().trim();
    if (name.isEmpty && location == null) return null;
    final rawDistance = row['distanceFromStartMeters'] ?? row['distance_from_start_meters'];
    final distanceFromStartMeters = rawDistance is num
        ? rawDistance.round()
        : (_parseDistanceMeters(row['distanceFromStart'] ?? row['distance_from_start'] ?? rawDistance) ?? 0);
    return StageWaypoint(
      id: (row['id'] ?? 'waypoint-$index').toString(),
      name: name.isEmpty ? 'Punkt ${index + 1}' : name,
      kind: _waypointKindFromLooseValue(row['kind'] ?? row['type'], fallback),
      location: location,
      category: (row['category'] ?? row['poiCategory'] ?? row['poi_category'] ?? '').toString(),
      note: (row['note'] ?? row['description'] ?? '').toString(),
      distanceFromStartMeters: distanceFromStartMeters,
    );
  }

  List<StageWaypoint> _stageWaypointsFromLooseJson(Map<String, dynamic> json, Map<String, dynamic> detail) {
    final out = <StageWaypoint>[];
    void addRows(dynamic raw, StageWaypointKind fallback) {
      if (raw is! List) return;
      for (final item in raw.whereType<Map>()) {
        final waypoint = _stageWaypointFromLooseJson(Map<String, dynamic>.from(item), fallback, out.length);
        if (waypoint != null && !out.any((existing) => existing.id == waypoint.id)) out.add(waypoint);
      }
    }
    addRows(json['waypoints'] ?? detail['waypoints'], StageWaypointKind.via);
    addRows(json['stops'] ?? detail['stops'], StageWaypointKind.stop);
    addRows(json['pois'] ?? json['poi'] ?? detail['pois'] ?? detail['poi'], StageWaypointKind.poi);
    return out;
  }

  Stage _stageFromLooseJson(Map<String, dynamic> json) {
    final row = (json['rowData'] ?? json['row_data']) is List ? List<dynamic>.from((json['rowData'] ?? json['row_data']) as List) : <dynamic>[];
    final detailRaw = json['detailData'] ?? json['detail_data'];
    final detail = detailRaw is Map ? Map<String, dynamic>.from(detailRaw) : <String, dynamic>{};
    final position = (json['position'] as num? ?? 0).round();
    final routeLabel = row.length > 1 ? row[1]?.toString() ?? '' : '';
    final routeParts = routeLabel.split('→').map((value) => value.trim()).where((value) => value.isNotEmpty).toList(growable: false);
    final routes = (detail['routes'] as List? ?? const []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
    final selectedRoute = (detail['selectedRoute'] ?? detail['selected_route'])?.toString();
    final start = routeParts.isNotEmpty ? routeParts.first : _routeEndpoint(routes, first: true) ?? 'Start';
    final end = routeParts.length > 1 ? routeParts.last : _routeEndpoint(routes, first: false) ?? (row.length > 4 ? row[4]?.toString() ?? 'Mål' : 'Mål');
    final directRoutes = (json['routeCandidates'] ?? json['route_candidates']) as List?;
    final candidateRows = directRoutes != null
        ? directRoutes.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false)
        : routes;
    final rawTransport = (json['transport'] ?? json['transportMode'] ?? json['transport_mode'] ?? detail['transportMode'] ?? (row.length > 11 ? row[11] : null) ?? 'walking').toString();
    final directSelectedRoute = (json['officialRouteId'] ?? json['official_route_id'] ?? selectedRoute)?.toString();
    final candidates = candidateRows.map((route) => _routeCandidateFromDesktop(route, directSelectedRoute)).toList(growable: false);
    return Stage(
      id: (json['id'] ?? (row.length > 10 ? row[10] : null) ?? 'stage-$position').toString(),
      day: _parseDay(json['day'] ?? (row.isNotEmpty ? row[0] : null), position),
      order: (json['order'] as num? ?? position).round(),
      name: (json['name'] ?? json['title'] ?? '').toString(),
      status: _stageStatusFromLooseValue(json['status']),
      start: (json['start'] ?? json['startLabel'] ?? json['start_label'] ?? start).toString(),
      end: (json['end'] ?? json['endLabel'] ?? json['end_label'] ?? end).toString(),
      transport: _transportFromLooseValue(rawTransport),
      distanceMeters: (json['distanceMeters'] as num?)?.round() ?? _parseDistanceMeters(json['distance'] ?? (row.length > 2 ? row[2] : null)) ?? (candidates.firstOrNull?.distanceMeters ?? 0),
      durationSeconds: (json['durationSeconds'] as num?)?.round() ?? _parseDurationSeconds(json['duration'] ?? (row.length > 3 ? row[3] : null)) ?? (candidates.firstOrNull?.durationSeconds ?? 0),
      routeCandidates: candidates,
      officialRouteId: directSelectedRoute ?? candidates.where((candidate) => candidate.official).firstOrNull?.id,
      routeProfile: (json['routeProfile'] ?? json['route_profile'] ?? detail['routeProfile'] ?? detail['route_profile'] ?? 'fastest').toString(),
      routePreferences: RoutePreferences.fromJson(
        (json['routePreferences'] ?? json['route_preferences'] ?? detail['routePreferences'] ?? detail['route_preferences']) is Map
            ? Map<String, dynamic>.from((json['routePreferences'] ?? json['route_preferences'] ?? detail['routePreferences'] ?? detail['route_preferences']) as Map)
            : null,
      ),
      waypoints: _stageWaypointsFromLooseJson(json, detail),
    );
  }

  RouteCandidate _routeCandidateFromDesktop(Map<String, dynamic> route, String? selectedRoute) {
    final id = (route['id'] ?? 'route-${route.hashCode}').toString();
    final geometry = (route['geometry'] as List? ?? const [])
        .map(_geoPointFromLooseValue)
        .whereType<GeoPoint>()
        .toList(growable: false);
    final maneuvers = (route['maneuvers'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) {
          final row = Map<String, dynamic>.from(raw);
          final location = _geoPointFromLooseValue(row['location'] ?? row['point']);
          if (location == null) return null;
          return NavigationManeuver(
            id: (row['id'] ?? 'maneuver-${row['sequence'] ?? 0}').toString(),
            sequence: (row['sequence'] as num? ?? 0).round(),
            type: (row['type'] ?? 'turn').toString(),
            modifier: (row['modifier'] ?? '').toString(),
            instruction: (row['instruction'] ?? 'Fortsett').toString(),
            location: location,
            roadName: (row['roadName'] ?? row['road_name'] ?? '').toString(),
            roadRef: (row['roadRef'] ?? row['road_ref'] ?? '').toString(),
            distanceMeters: (row['distanceMeters'] as num? ?? row['distance_meters'] as num? ?? 0).round(),
            durationSeconds: (row['durationSeconds'] as num? ?? row['duration_seconds'] as num? ?? 0).round(),
            distanceFromStartMeters: (row['distanceFromStartMeters'] as num? ?? row['distance_from_start_meters'] as num? ?? 0).round(),
            exit: (row['exit'] as num?)?.round(),
            source: (row['source'] ?? route['guidanceSource'] ?? route['guidance_source'] ?? 'none').toString(),
            confidence: (row['confidence'] as num? ?? 0).toDouble(),
          );
        })
        .whereType<NavigationManeuver>()
        .toList(growable: false);
    return RouteCandidate(
      id: id,
      name: (route['name'] ?? 'Rute').toString(),
      distanceMeters: _parseDistanceMeters(route['distance']) ?? (route['distanceMeters'] as num? ?? 0).round(),
      durationSeconds: _parseDurationSeconds(route['duration']) ?? (route['durationSeconds'] as num? ?? 0).round(),
      geometry: geometry,
      maneuvers: maneuvers,
      guidanceSource: (route['guidanceSource'] ?? route['guidance_source'] ?? (maneuvers.isEmpty ? 'none' : 'handoff')).toString(),
      official: selectedRoute == id || route['official'] == true || route['status']?.toString().toLowerCase() == 'valgt',
    );
  }


  GeoPoint? _geoPointFromLooseValue(dynamic value) {
    if (value is List && value.length >= 2 && value[0] is num && value[1] is num) {
      return GeoPoint(lon: (value[0] as num).toDouble(), lat: (value[1] as num).toDouble());
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final lat = map['lat'] ?? map['latitude'];
      final lon = map['lon'] ?? map['lng'] ?? map['longitude'];
      if (lat is num && lon is num) return GeoPoint(lat: lat.toDouble(), lon: lon.toDouble(), label: map['name']?.toString());
      final coord = map['coord'] ?? map['coordinates'];
      if (coord is List && coord.length >= 2 && coord[0] is num && coord[1] is num) {
        return GeoPoint(lon: (coord[0] as num).toDouble(), lat: (coord[1] as num).toDouble(), label: map['name']?.toString());
      }
    }
    return null;
  }

  String? _routeEndpoint(List<Map<String, dynamic>> routes, {required bool first}) {
    if (routes.isEmpty) return null;
    final points = routes.first['points'];
    if (points is! List || points.isEmpty) return null;
    final value = first ? points.first : points.last;
    if (value is Map) return (value['name'] ?? value['label'])?.toString();
    return null;
  }

  StageTransport _transportFromLooseValue(String raw) => switch (raw.trim().toLowerCase()) {
        'motorcycle' || 'mc' => StageTransport.motorcycle,
        'car' || 'driving' => StageTransport.car,
        'cycling' || 'bicycle' || 'bike' => StageTransport.cycling,
        'train' || 'rail' => StageTransport.train,
        'ferry' => StageTransport.ferry,
        _ => StageTransport.walking,
      };

  int _parseDay(dynamic value, int fallback) {
    if (value is num) return value.round();
    final match = RegExp(r'(\d+)').firstMatch(value?.toString() ?? '');
    return match == null ? fallback : int.tryParse(match.group(1)!) ?? fallback;
  }

  int? _parseDistanceMeters(dynamic value) {
    if (value is num) return value.round();
    final text = value?.toString().trim().toLowerCase().replaceAll(',', '.') ?? '';
    if (text.isEmpty || text == '—') return null;
    final number = double.tryParse(RegExp(r'[0-9]+(?:\.[0-9]+)?').firstMatch(text)?.group(0) ?? '');
    if (number == null) return null;
    return text.contains('km') ? (number * 1000).round() : number.round();
  }

  int? _parseDurationSeconds(dynamic value) {
    if (value is num) return value.round();
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty || text == '—') return null;
    final clock = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
    if (clock != null) return (int.parse(clock.group(1)!) * 60 + int.parse(clock.group(2)!)) * 60;
    final hours = RegExp(r'([0-9]+(?:[.,][0-9]+)?)\s*(?:t|h|time)').firstMatch(text);
    final minutes = RegExp(r'(\d+)\s*(?:m|min)').firstMatch(text);
    if (hours == null && minutes == null) return null;
    final h = double.tryParse((hours?.group(1) ?? '0').replaceAll(',', '.')) ?? 0;
    final m = int.tryParse(minutes?.group(1) ?? '0') ?? 0;
    return (h * 3600).round() + m * 60;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }

  bool _canBeActiveTrip(Trip trip) => trip.status == TripStatus.active || trip.status == TripStatus.planned;

  Trip _copyTrip(Trip trip, {DateTime? endDate, TripStatus? status, List<Stage>? stages}) => Trip(
        id: trip.id,
        name: trip.name,
        startDate: trip.startDate,
        endDate: endDate ?? trip.endDate,
        start: trip.start,
        end: trip.end,
        status: status ?? trip.status,
        ownerId: trip.ownerId,
        stages: stages ?? trip.stages,
        participants: trip.participants,
        offlineReady: trip.offlineReady,
      );

  List<Trip> _mergeLocalTripSnapshots(List<Trip> baseTrips) {
    final snapshots = store.readJson('local_trip_snapshots') ?? const <String, dynamic>{};
    final byId = <String, Trip>{for (final trip in baseTrips) trip.id: trip};
    for (final entry in snapshots.entries) {
      if (entry.value is! Map) continue;
      final local = _tripFromSnapshot(Map<String, dynamic>.from(entry.value as Map));
      if (local.id.isEmpty) continue;
      final current = byId[local.id];
      if (current == null || (current.stages.isEmpty && local.stages.isNotEmpty) || local.ownerId.isEmpty) {
        byId[local.id] = local;
      }
    }
    final result = byId.values.toList(growable: false);
    result.sort((a, b) => b.startDate.compareTo(a.startDate));
    return result;
  }

  Future<void> _persistLocalTripSnapshot(Trip trip) async {
    final snapshots = store.readJson('local_trip_snapshots') ?? <String, dynamic>{};
    snapshots[trip.id] = _tripToSnapshot(trip);
    await store.writeJson('local_trip_snapshots', snapshots);
  }

  Future<void> _removeLocalTripSnapshot(String tripId) async {
    final snapshots = store.readJson('local_trip_snapshots') ?? <String, dynamic>{};
    if (snapshots.remove(tripId) != null) await store.writeJson('local_trip_snapshots', snapshots);
  }

  List<Trip> _mergeCompletedSnapshots(List<Trip> cloudTrips) {
    final snapshots = store.readJson('completed_trip_snapshots') ?? const <String, dynamic>{};
    final byId = <String, Trip>{for (final trip in cloudTrips) trip.id: trip};
    for (final entry in snapshots.entries) {
      if (entry.value is! Map) continue;
      final snapshot = _tripFromSnapshot(Map<String, dynamic>.from(entry.value as Map));
      final cloud = byId[entry.key];
      if (cloud == null) {
        byId[entry.key] = snapshot;
      } else if (cloud.status == TripStatus.completed && cloud.stages.isEmpty && snapshot.stages.isNotEmpty) {
        byId[entry.key] = _copyTrip(cloud, stages: snapshot.stages, endDate: snapshot.endDate);
      }
    }
    final result = byId.values.toList(growable: false);
    result.sort((a, b) => b.startDate.compareTo(a.startDate));
    return result;
  }

  Map<String, dynamic> _tripToSnapshot(Trip trip) => {
        'id': trip.id,
        'name': trip.name,
        'startDate': trip.startDate.toIso8601String(),
        'endDate': trip.endDate.toIso8601String(),
        'start': trip.start,
        'end': trip.end,
        'status': trip.status.name,
        'ownerId': trip.ownerId,
        'stages': [for (final stage in trip.stages) _stageToSnapshot(stage)],
      };

  Map<String, dynamic> _stageToSnapshot(Stage stage) => {
        'id': stage.id,
        'day': stage.day,
        'order': stage.order,
        'name': stage.name,
        'status': stage.status.name,
        'routeId': stage.officialRouteId ?? stage.id,
        'start': stage.start,
        'end': stage.end,
        'transport': stage.transport.name,
        'distanceMeters': stage.distanceMeters,
        'waypoints': stage.waypoints.map((item) => item.toJson()).toList(growable: false),
        'durationSeconds': stage.durationSeconds,
        'officialRouteId': stage.officialRouteId,
        'routeProfile': stage.routeProfile,
        'routePreferences': stage.routePreferences.toJson(),
        'routeCandidates': [
          for (final route in stage.routeCandidates)
            {
              'id': route.id,
              'name': route.name,
              'distanceMeters': route.distanceMeters,
              'durationSeconds': route.durationSeconds,
              'official': route.official,
              'guidanceSource': route.guidanceSource,
              'geometry': [for (final point in route.geometry) [point.lon, point.lat]],
              'maneuvers': [
                for (final maneuver in route.maneuvers) maneuver.toJson()
              ],
            }
        ],
      };

  Trip _tripFromSnapshot(Map<String, dynamic> json) => Trip(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Tur',
        startDate: _parseDate(json['startDate']) ?? DateTime.now(),
        endDate: _parseDate(json['endDate']) ?? DateTime.now(),
        start: json['start']?.toString() ?? 'Start',
        end: json['end']?.toString() ?? 'Mål',
        status: TripStatus.values.where((value) => value.name == json['status']).firstOrNull ?? TripStatus.completed,
        ownerId: json['ownerId']?.toString() ?? '',
        stages: (json['stages'] as List? ?? const []).whereType<Map>().map((row) {
          final map = Map<String, dynamic>.from(row);
          final routes = (map['routeCandidates'] as List? ?? const []).whereType<Map>().map((routeRow) {
            final route = Map<String, dynamic>.from(routeRow);
            final geometry = (route['geometry'] as List? ?? const []).whereType<List>().where((p) => p.length >= 2 && p[0] is num && p[1] is num).map((p) => GeoPoint(lon: (p[0] as num).toDouble(), lat: (p[1] as num).toDouble())).toList(growable: false);
            final maneuvers = (route['maneuvers'] as List? ?? const []).whereType<Map>().map((mRow) {
              final maneuver = Map<String, dynamic>.from(mRow);
              final location = maneuver['location'];
              final point = location is List && location.length >= 2 && location[0] is num && location[1] is num
                  ? GeoPoint(lon: (location[0] as num).toDouble(), lat: (location[1] as num).toDouble())
                  : const GeoPoint(lon: 0, lat: 0);
              return NavigationManeuver(
                id: maneuver['id']?.toString() ?? '',
                sequence: (maneuver['sequence'] as num? ?? 0).round(),
                type: maneuver['type']?.toString() ?? 'turn',
                modifier: maneuver['modifier']?.toString() ?? '',
                instruction: maneuver['instruction']?.toString() ?? '',
                roadName: maneuver['roadName']?.toString() ?? '',
                roadRef: maneuver['roadRef']?.toString() ?? '',
                distanceMeters: (maneuver['distanceMeters'] as num? ?? 0).round(),
                durationSeconds: (maneuver['durationSeconds'] as num? ?? 0).round(),
                distanceFromStartMeters: (maneuver['distanceFromStartMeters'] as num? ?? 0).round(),
                exit: maneuver['exit'] is num ? (maneuver['exit'] as num).round() : null,
                source: maneuver['source']?.toString() ?? 'none',
                confidence: (maneuver['confidence'] as num? ?? 0).toDouble(),
                location: point,
              );
            }).toList(growable: false);
            return RouteCandidate(
              id: route['id']?.toString() ?? '',
              name: route['name']?.toString() ?? 'Rute',
              distanceMeters: (route['distanceMeters'] as num? ?? 0).round(),
              durationSeconds: (route['durationSeconds'] as num? ?? 0).round(),
              geometry: geometry,
              maneuvers: maneuvers,
              guidanceSource: route['guidanceSource']?.toString() ?? 'none',
              official: route['official'] == true,
            );
          }).toList(growable: false);
          return Stage(
            id: map['id']?.toString() ?? '',
            day: (map['day'] as num? ?? 0).round(),
            order: (map['order'] as num? ?? 0).round(),
            name: map['name']?.toString() ?? '',
            status: _stageStatusFromLooseValue(map['status']),
            start: map['start']?.toString() ?? 'Start',
            end: map['end']?.toString() ?? 'Mål',
            transport: _transportFromLooseValue(map['transport']?.toString() ?? 'walking'),
            distanceMeters: (map['distanceMeters'] as num? ?? 0).round(),
            durationSeconds: (map['durationSeconds'] as num? ?? 0).round(),
            routeCandidates: routes,
            officialRouteId: map['officialRouteId']?.toString(),
            routeProfile: map['routeProfile']?.toString() ?? 'fastest',
            routePreferences: RoutePreferences.fromJson(
              map['routePreferences'] is Map ? Map<String, dynamic>.from(map['routePreferences'] as Map) : null,
            ),
            waypoints: _stageWaypointsFromLooseJson(map, const <String, dynamic>{}),
          );
        }).toList(growable: false),
      );

  Future<void> _flushPendingTripStatusUpdates() async {
    if (!auth.signedIn) return;
    final pending = store.readJson('pending_trip_status_updates') ?? <String, dynamic>{};
    if (pending.isEmpty) return;
    final remaining = <String, dynamic>{...pending};
    for (final entry in pending.entries) {
      try {
        final currentResult = await api.domain('trip', 'getById', [entry.key]);
        final currentRaw = _unwrapScalar(currentResult);
        if (currentRaw is! Map) {
          remaining.remove(entry.key);
          continue;
        }
        final current = Map<String, dynamic>.from(currentRaw);
        final meta = entry.value is Map ? Map<String, dynamic>.from(entry.value as Map) : <String, dynamic>{};
        current['status'] = meta['status'] ?? 'Fullført';
        if (meta['completedAt'] != null) {
          current['endDate'] = meta['completedAt'];
        }
        await api.domain('trip', 'update', [current]);
        remaining.remove(entry.key);
      } catch (_) {
        // Keep queued. Offline completion must not disappear from local history.
      }
    }
    await store.writeJson('pending_trip_status_updates', remaining);
  }

}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
