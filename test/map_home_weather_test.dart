import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:govia_mobile/app/app_state.dart';
import 'package:govia_mobile/core/network/api_client.dart';
import 'package:govia_mobile/core/storage/local_store.dart';
import 'package:govia_mobile/core/widgets/govia_widgets.dart';
import 'package:govia_mobile/domain/models.dart';
import 'package:govia_mobile/features/auth/auth_service.dart';

class _Auth extends Fake implements AuthService {
  @override
  Future<void> stopTripNotificationRealtime() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bergen = GeoPoint(lat: 60.39, lon: 5.32);
  Map<String, dynamic> forecast(GeoPoint point, double min) {
    final now = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return {'data': {'providerLabel': 'GoVia weather', 'days': [
      {'date': date, 'points': [
        {'lat': point.lat, 'lon': point.lon, 'tempMin': min, 'tempMax': min + 5, 'windMax': 4, 'precipMm': 1},
      ]},
    ]}};
  }
  Future<AppState> stateFor(Future<http.Response> Function(http.Request) handler) async {
    SharedPreferences.setMockInitialValues({});
    return AppState(auth: _Auth(), api: ApiClient(client: MockClient(handler)), store: await LocalStore.create());
  }

  test('local daily forecast works without a selected trip and reuses the cache', () async {
    var calls = 0;
    final state = await stateFor((request) async {
      calls++;
      expect(request.url.path, '/api/v1/weather/route');
      final body = jsonDecode(request.body) as Map;
      expect(body['points'], [[5.32, 60.39], [5.32, 60.39]]);
      expect(body.containsKey('tripId'), isFalse);
      return http.Response(jsonEncode(forecast(bergen, 8)), 200);
    });
    await state.refreshMapWeather(bergen);
    expect(state.activeTrip, isNull);
    expect(state.mapWeather!.points.first.tempMin, 8);
    expect(state.weather, isEmpty);
    await state.refreshMapWeather(bergen, label: 'Min posisjon');
    expect(calls, 1);
    expect(state.mapWeatherLocation, 'Min posisjon');
    await state.refreshMapWeather(bergen, force: true);
    expect(calls, 2);
    state.dispose();
  });

  test('weather entitlement rejection has an actionable message', () async {
    final state = await stateFor((_) async => http.Response(jsonEncode({'error': {'code': 'capability_required', 'message': 'Denied'}}), 403));
    await state.refreshMapWeather(bergen);
    expect(state.mapWeather, isNull);
    expect(state.mapWeatherLoading, isFalse);
    expect(state.mapWeatherMessage, contains('aktiv for kontoen'));
    state.dispose();
  });

  test('a slow response for an old map area cannot overwrite the latest area', () async {
    final old = Completer<http.Response>();
    var calls = 0;
    const oslo = GeoPoint(lat: 59.91, lon: 10.75);
    final state = await stateFor((_) async {
      calls++;
      if (calls == 1) return old.future;
      return http.Response(jsonEncode(forecast(oslo, 12)), 200);
    });
    final pending = state.refreshMapWeather(bergen);
    await Future<void>.delayed(Duration.zero);
    await state.refreshMapWeather(oslo);
    old.complete(http.Response(jsonEncode(forecast(bergen, 8)), 200));
    await pending;
    expect(state.mapWeather!.points.first.lon, oslo.lon);
    expect(state.mapWeather!.points.first.tempMin, 12);
    expect(state.mapWeatherLoading, isFalse);
    state.dispose();
  });

  test('canonical logo is included in the Flutter asset bundle', () async {
    final bytes = await rootBundle.load(GoViaLogo.assetPath);
    expect(bytes.lengthInBytes, greaterThan(0));
    expect(bytes.buffer.asUint8List(bytes.offsetInBytes, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });
}
