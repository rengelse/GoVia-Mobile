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

class RouteCandidate {
  const RouteCandidate({
    required this.id,
    required this.name,
    required this.distanceMeters,
    required this.durationSeconds,
    this.geometry = const [],
    this.official = false,
  });
  final String id;
  final String name;
  final int distanceMeters;
  final int durationSeconds;
  final List<GeoPoint> geometry;
  final bool official;

  RouteCandidate copyWith({bool? official}) => RouteCandidate(
        id: id,
        name: name,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        geometry: geometry,
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
  const ChatMessage({required this.id, required this.sender, required this.text, required this.sentAt, this.mine = false});
  final String id;
  final String sender;
  final String text;
  final DateTime sentAt;
  final bool mine;
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
