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

class Stage {
  const Stage({
    required this.id,
    required this.day,
    required this.order,
    required this.start,
    required this.end,
    required this.transport,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.routeCandidates = const [],
    this.officialRouteId,
  });
  final String id;
  final int day;
  final int order;
  final String start;
  final String end;
  final StageTransport transport;
  final int distanceMeters;
  final int durationSeconds;
  final List<RouteCandidate> routeCandidates;
  final String? officialRouteId;
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
    this.description = '',
    this.geometry = const [],
    this.tags = const [],
    this.photoUrls = const [],
    this.saved = false,
  });

  final String id;
  final String title;
  final String authorName;
  final StageTransport transport;
  final String start;
  final String end;
  final int distanceMeters;
  final int durationSeconds;
  final String description;
  final List<GeoPoint> geometry;
  final List<String> tags;
  final List<String> photoUrls;
  final bool saved;
}
