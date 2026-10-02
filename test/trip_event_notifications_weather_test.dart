import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/features/notifications/data/cloud_notification_mapper.dart';
import 'package:govia_mobile/features/notifications/domain/govia_notification.dart';
import 'package:govia_mobile/features/weather/data/trip_weather_parser.dart';

void main() {
  Map<String, dynamic> cloudRow({String? actorId, List<String>? recipients}) => {
        'id': 'notification-1',
        'trip_id': 'trip-1',
        'type': 'stage_updated',
        'actor_id': actorId,
        'title': 'Etappe oppdatert',
        'message': 'Dag 2 er endret.',
        'target_page': 'stages',
        'target_stage_id': 'stage-2',
        'target_id': 'stage-2',
        'recipients': recipients ?? const ['user-1'],
        'read_by': const [],
        'created_at': '2026-10-02T08:30:00Z',
      };

  test('cloud trip event suppresses changes made by the current user', () {
    final result = CloudNotificationMapper.fromTripNotificationRow(
      cloudRow(actorId: 'user-1'),
      currentUserId: 'user-1',
    );
    expect(result, isNull);
  });

  test('cloud trip event from another member becomes a stage notification', () {
    final result = CloudNotificationMapper.fromTripNotificationRow(
      cloudRow(actorId: 'user-2'),
      currentUserId: 'user-1',
    );
    expect(result, isNotNull);
    expect(result!.id, 'cloud-notification-1');
    expect(result.type, GoViaNotificationType.navigation);
    expect(result.target.type, GoViaNotificationTargetType.stage);
    expect(result.target.tripId, 'trip-1');
    expect(result.target.stageId, 'stage-2');
    expect(result.metadata['actorUserId'], 'user-2');
  });

  test('system trip event remains deliverable without actor', () {
    final result = CloudNotificationMapper.fromTripNotificationRow(
      cloudRow(),
      currentUserId: 'user-1',
    );
    expect(result, isNotNull);
  });

  test('non-recipient never receives cloud trip event', () {
    final result = CloudNotificationMapper.fromTripNotificationRow(
      cloudRow(actorId: 'user-2', recipients: const ['user-3']),
      currentUserId: 'user-1',
    );
    expect(result, isNull);
  });

  test('route weather respects the nine-day forecast window', () {
    final now = DateTime(2026, 10, 2, 12);
    expect(TripWeatherParser.withinForecastWindow(DateTime(2026, 10, 10), now), isTrue);
    expect(TripWeatherParser.daysToRequest(DateTime(2026, 10, 10), now), 9);
    expect(TripWeatherParser.withinForecastWindow(DateTime(2026, 10, 11), now), isFalse);
  });

  test('route weather parses the selected trip date and route points', () {
    final parsed = TripWeatherParser.parseForDate({
      'data': {
        'provider': 'met_no',
        'providerLabel': 'MET Norway (Yr)',
        'generatedAt': '2026-10-02T08:00:00Z',
        'days': [
          {
            'date': '2026-10-03',
            'summary': {'tempMin': 3, 'tempMax': 11, 'precipMm': 4.2},
            'points': [
              {'lon': 5.32, 'lat': 60.39, 'tempMin': 4, 'tempMax': 8, 'precipMm': 1.2, 'windMax': 5, 'symbolCode': 'rain'},
              {'lon': 7.99, 'lat': 58.14, 'tempMin': 3, 'tempMax': 11, 'precipMm': 3.0, 'windMax': 9, 'symbolCode': 'cloudy'},
            ],
          },
        ],
      },
    }, DateTime(2026, 10, 3));

    expect(parsed, isNotNull);
    expect(parsed!.provider, 'met_no');
    expect(parsed.points.length, 2);
    expect(parsed.points.first.label, 'Start');
    expect(parsed.points.last.label, 'Mål');
    expect(parsed.points.last.wind, 9);
  });

  test('mobile uses existing shared notification and route-weather contracts', () {
    final auth = File('lib/features/auth/auth_service.dart').readAsStringSync();
    final state = File('lib/app/app_state.dart').readAsStringSync();
    expect(auth, contains("from('trip_notifications')"));
    expect(auth, contains("contains('recipients', [uid])"));
    expect(state, contains("api.postJson('/api/v1/weather/route'"));
    expect(state, contains("'tripId': trip.id"));
    expect(state, contains("'points': points"));
    expect(state, isNot(contains('api.met.no')));
  });
}
