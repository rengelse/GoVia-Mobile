import 'dart:convert';

class GeoPoint {
  const GeoPoint({required this.lat, required this.lon, this.label});
  final double lat;
  final double lon;
  final String? label;

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon, 'label': label};
  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        label: json['label'] as String?,
      );
}

enum StageTransport { motorcycle, car, walking, cycling, train, ferry }

enum TripStatus { planned, active, completed, archived }

enum StageStatus { planned, active, completed }

enum StageWaypointKind { via, stop, poi }

class StageWaypoint {
  const StageWaypoint({
    required this.id,
    required this.name,
    required this.kind,
    this.location,
    this.category = '',
    this.note = '',
    this.distanceFromStartMeters = 0,
  });

  final String id;
  final String name;
  final StageWaypointKind kind;
  final GeoPoint? location;
  final String category;
  final String note;
  final int distanceFromStartMeters;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'category': category,
        'note': note,
        'distanceFromStartMeters': distanceFromStartMeters,
        if (location != null) 'location': [location!.lon, location!.lat],
      };
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.displayName = '',
    this.bio = '',
    this.location = '',
    this.avatarUrl,
    this.preferredTransport = StageTransport.motorcycle,
    this.unitSystem = 'metric',
    this.voiceEnabled = true,
    this.locationSharing = 'active_trip',
    this.profilePublic = true,
    this.showPublishedRoutes = true,
    this.allowRouteRatings = true,
  });

  final String id;
  final String email;
  final String displayName;
  final String bio;
  final String location;
  final String? avatarUrl;
  final StageTransport preferredTransport;
  final String unitSystem;
  final bool voiceEnabled;
  final String locationSharing;
  final bool profilePublic;
  final bool showPublishedRoutes;
  final bool allowRouteRatings;

  UserProfile copyWith({
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
  }) => UserProfile(
        id: id,
        email: email,
        displayName: displayName ?? this.displayName,
        bio: bio ?? this.bio,
        location: location ?? this.location,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        preferredTransport: preferredTransport ?? this.preferredTransport,
        unitSystem: unitSystem ?? this.unitSystem,
        voiceEnabled: voiceEnabled ?? this.voiceEnabled,
        locationSharing: locationSharing ?? this.locationSharing,
        profilePublic: profilePublic ?? this.profilePublic,
        showPublishedRoutes: showPublishedRoutes ?? this.showPublishedRoutes,
        allowRouteRatings: allowRouteRatings ?? this.allowRouteRatings,
      );
}

class NavigationManeuver {
  const NavigationManeuver({
    required this.id,
    required this.sequence,
    required this.type,
    required this.instruction,
    required this.location,
    this.modifier = '',
    this.roadName = '',
    this.roadRef = '',
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.distanceFromStartMeters = 0,
    this.exit,
    this.source = 'none',
    this.confidence = 0,
  });
  final String id;
  final int sequence;
  final String type;
  final String modifier;
  final String instruction;
  final GeoPoint location;
  final String roadName;
  final String roadRef;
  final int distanceMeters;
  final int durationSeconds;
  final int distanceFromStartMeters;
  final int? exit;
  final String source;
  final double confidence;

  factory NavigationManeuver.fromJson(Map<String, dynamic> json) {
    final location = json['location'];
    if (location is! List || location.length < 2) {
      throw const FormatException('Maneuver mangler koordinat.');
    }
    return NavigationManeuver(
      id: json['id']?.toString() ?? 'maneuver-${json['sequence'] ?? 0}',
      sequence: (json['sequence'] as num? ?? 0).round(),
      type: json['type']?.toString() ?? 'turn',
      modifier: json['modifier']?.toString() ?? '',
      instruction: json['instruction']?.toString() ?? 'Fortsett',
      roadName: json['roadName']?.toString() ?? '',
      roadRef: json['roadRef']?.toString() ?? '',
      distanceMeters: (json['distanceMeters'] as num? ?? 0).round(),
      durationSeconds: (json['durationSeconds'] as num? ?? 0).round(),
      distanceFromStartMeters: (json['distanceFromStartMeters'] as num? ?? 0).round(),
      location: GeoPoint(lat: (location[1] as num).toDouble(), lon: (location[0] as num).toDouble()),
      exit: (json['exit'] as num?)?.round(),
      source: json['source']?.toString() ?? 'none',
      confidence: (json['confidence'] as num? ?? 0).toDouble(),
    );
  }
}

class RouteCandidate {
  const RouteCandidate({
    required this.id,
    required this.name,
    required this.distanceMeters,
    required this.durationSeconds,
    this.geometry = const [],
    this.maneuvers = const [],
    this.guidanceSource = 'none',
    this.official = false,
  });
  final String id;
  final String name;
  final int distanceMeters;
  final int durationSeconds;
  final List<GeoPoint> geometry;
  final List<NavigationManeuver> maneuvers;
  final String guidanceSource;
  final bool official;

  RouteCandidate copyWith({bool? official, List<NavigationManeuver>? maneuvers, String? guidanceSource}) => RouteCandidate(
        id: id,
        name: name,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        geometry: geometry,
        maneuvers: maneuvers ?? this.maneuvers,
        guidanceSource: guidanceSource ?? this.guidanceSource,
        official: official ?? this.official,
      );
}

class RoutePreferences {
  const RoutePreferences({
    this.avoidMotorways = false,
    this.avoidTolls = false,
    this.avoidFerries = false,
    this.avoidUnpaved = false,
    this.avoidCities = false,
    this.preferScenic = false,
    this.preferCoastal = false,
    this.preferMountains = false,
  });

  final bool avoidMotorways;
  final bool avoidTolls;
  final bool avoidFerries;
  final bool avoidUnpaved;
  final bool avoidCities;
  final bool preferScenic;
  final bool preferCoastal;
  final bool preferMountains;

  RoutePreferences copyWith({
    bool? avoidMotorways,
    bool? avoidTolls,
    bool? avoidFerries,
    bool? avoidUnpaved,
    bool? avoidCities,
    bool? preferScenic,
    bool? preferCoastal,
    bool? preferMountains,
  }) => RoutePreferences(
        avoidMotorways: avoidMotorways ?? this.avoidMotorways,
        avoidTolls: avoidTolls ?? this.avoidTolls,
        avoidFerries: avoidFerries ?? this.avoidFerries,
        avoidUnpaved: avoidUnpaved ?? this.avoidUnpaved,
        avoidCities: avoidCities ?? this.avoidCities,
        preferScenic: preferScenic ?? this.preferScenic,
        preferCoastal: preferCoastal ?? this.preferCoastal,
        preferMountains: preferMountains ?? this.preferMountains,
      );

  Map<String, dynamic> toJson() => {
        'avoidMotorways': avoidMotorways,
        'avoidTolls': avoidTolls,
        'avoidFerries': avoidFerries,
        'avoidUnpaved': avoidUnpaved,
        'avoidCities': avoidCities,
        'preferScenic': preferScenic,
        'preferCoastal': preferCoastal,
        'preferMountains': preferMountains,
      };

  factory RoutePreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RoutePreferences();
    return RoutePreferences(
      avoidMotorways: json['avoidMotorways'] == true || json['avoid_motorways'] == true,
      avoidTolls: json['avoidTolls'] == true || json['avoid_tolls'] == true,
      avoidFerries: json['avoidFerries'] == true || json['avoid_ferries'] == true,
      avoidUnpaved: json['avoidUnpaved'] == true || json['avoid_unpaved'] == true,
      avoidCities: json['avoidCities'] == true || json['avoid_cities'] == true,
      preferScenic: json['preferScenic'] == true || json['prefer_scenic'] == true,
      preferCoastal: json['preferCoastal'] == true || json['prefer_coastal'] == true,
      preferMountains: json['preferMountains'] == true || json['prefer_mountains'] == true,
    );
  }
}

class Stage {
  const Stage({
    required this.id,
    required this.day,
    required this.order,
    required this.start,
    required this.end,
    required this.transport,
    this.name = '',
    this.status = StageStatus.planned,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.routeCandidates = const [],
    this.officialRouteId,
    this.routeProfile = 'fastest',
    this.routePreferences = const RoutePreferences(),
    this.waypoints = const [],
  });
  final String id;
  final int day;
  final int order;
  final String start;
  final String end;
  final StageTransport transport;
  final String name;
  final StageStatus status;
  final int distanceMeters;
  final int durationSeconds;
  final List<RouteCandidate> routeCandidates;
  final String? officialRouteId;
  final String routeProfile;
  final RoutePreferences routePreferences;
  final List<StageWaypoint> waypoints;

  List<StageWaypoint> get pois => waypoints.where((item) => item.kind == StageWaypointKind.poi).toList(growable: false);
  List<StageWaypoint> get stops => waypoints.where((item) => item.kind == StageWaypointKind.stop).toList(growable: false);
  List<StageWaypoint> get viaPoints => waypoints.where((item) => item.kind == StageWaypointKind.via).toList(growable: false);

  Stage copyWith({
    String? name,
    StageStatus? status,
    int? distanceMeters,
    int? durationSeconds,
    List<RouteCandidate>? routeCandidates,
    String? officialRouteId,
    String? routeProfile,
    RoutePreferences? routePreferences,
    List<StageWaypoint>? waypoints,
  }) => Stage(
        id: id,
        day: day,
        order: order,
        start: start,
        end: end,
        transport: transport,
        name: name ?? this.name,
        status: status ?? this.status,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        routeCandidates: routeCandidates ?? this.routeCandidates,
        officialRouteId: officialRouteId ?? this.officialRouteId,
        routeProfile: routeProfile ?? this.routeProfile,
        routePreferences: routePreferences ?? this.routePreferences,
        waypoints: waypoints ?? this.waypoints,
      );
}

class Participant {
  const Participant({
    required this.id,
    required this.name,
    this.role = 'member',
    this.online = false,
    this.avatarUrl,
  });
  final String id;
  final String name;
  final String role;
  final bool online;
  final String? avatarUrl;
}

class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.start,
    required this.end,
    required this.status,
    this.ownerId = '',
    this.stages = const [],
    this.participants = const [],
    this.offlineReady = false,
  });
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String start;
  final String end;
  final TripStatus status;
  final String ownerId;
  final List<Stage> stages;
  final List<Participant> participants;
  final bool offlineReady;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.sentAt,
    this.senderId = '',
    this.mine = false,
    this.editedAt,
    this.deletedAt,
    this.likeCount = 0,
    this.likedByMe = false,
  });
  final String id;
  final String sender;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final bool mine;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final int likeCount;
  final bool likedByMe;

  bool get deleted => deletedAt != null;

  ChatMessage copyWith({String? text, DateTime? editedAt, DateTime? deletedAt, int? likeCount, bool? likedByMe}) => ChatMessage(
        id: id,
        sender: sender,
        senderId: senderId,
        text: text ?? this.text,
        sentAt: sentAt,
        mine: mine,
        editedAt: editedAt ?? this.editedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
      );
}

class WeatherPoint {
  const WeatherPoint({required this.label, required this.temperature, required this.wind, required this.precipitation});
  final String label;
  final double temperature;
  final double wind;
  final double precipitation;
}

class PoiItem {
  const PoiItem({required this.id, required this.name, required this.category, required this.distanceMeters});
  final String id;
  final String name;
  final String category;
  final int distanceMeters;
}

String transportLabel(StageTransport value) => switch (value) {
      StageTransport.motorcycle => 'Motorsykkel',
      StageTransport.car => 'Bil',
      StageTransport.walking => 'Gange',
      StageTransport.cycling => 'Sykkel',
      StageTransport.train => 'Tog',
      StageTransport.ferry => 'Ferge',
    };

String compactJson(Object value) => jsonEncode(value);

class RouteRating {
  const RouteRating({required this.experience, required this.scenery, required this.surface});
  final double experience;
  final double scenery;
  final double surface;
  double get overall => (experience + scenery + surface) / 3;
}

class ElevationSample {
  const ElevationSample({required this.distanceMeters, required this.elevationMeters});
  final int distanceMeters;
  final int elevationMeters;
}

class ElevationProfile {
  const ElevationProfile({required this.samples, required this.ascentMeters, required this.descentMeters, required this.minElevationMeters, required this.maxElevationMeters, this.source = ''});
  final List<ElevationSample> samples;
  final int ascentMeters;
  final int descentMeters;
  final int minElevationMeters;
  final int maxElevationMeters;
  final String source;
}

class PublishedRoutePhoto {
  const PublishedRoutePhoto({
    required this.id,
    required this.url,
    this.caption = '',
    this.lat,
    this.lon,
    this.position = 0,
  });

  final String id;
  final String url;
  final String caption;
  final double? lat;
  final double? lon;
  final int position;
}

class PublishedRoute {
  const PublishedRoute({
    required this.id,
    required this.title,
    required this.authorName,
    required this.transport,
    required this.start,
    required this.end,
    required this.distanceMeters,
    required this.durationSeconds,
    this.authorId = '',
    this.description = '',
    this.geometry = const [],
    this.tags = const [],
    this.photos = const [],
    this.saved = false,
    this.ratingCount = 0,
    this.rating,
    this.myRating,
    this.allowRatings = true,
    this.visibility = 'public',
    this.status = 'published',
    this.sourceTripId,
    this.sourceStageId,
  });

  final String id;
  final String title;
  final String authorId;
  final String authorName;
  final StageTransport transport;
  final String start;
  final String end;
  final int distanceMeters;
  final int durationSeconds;
  final String description;
  final List<GeoPoint> geometry;
  final List<String> tags;
  final List<PublishedRoutePhoto> photos;
  final bool saved;
  final int ratingCount;
  final RouteRating? rating;
  final RouteRating? myRating;
  final bool allowRatings;
  final String visibility;
  final String status;
  final String? sourceTripId;
  final String? sourceStageId;

  List<String> get photoUrls => photos.map((photo) => photo.url).where((url) => url.isNotEmpty).toList(growable: false);
}
