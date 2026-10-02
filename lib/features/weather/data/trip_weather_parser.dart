import '../../../domain/models.dart';

class TripWeatherDay {
  const TripWeatherDay({
    required this.date,
    required this.points,
    this.provider = '',
    this.providerLabel = '',
    this.generatedAt,
  });

  final DateTime date;
  final List<WeatherPoint> points;
  final String provider;
  final String providerLabel;
  final DateTime? generatedAt;
}

class TripWeatherParser {
  const TripWeatherParser._();

  static TripWeatherDay? parseForDate(Map<String, dynamic> response, DateTime targetDate) {
    final dataRaw = response['data'] ?? response;
    if (dataRaw is! Map) return null;
    final data = Map<String, dynamic>.from(dataRaw);
    final days = data['days'];
    if (days is! List) return null;
    final targetKey = _dateKey(targetDate);
    Map<String, dynamic>? selected;
    for (final raw in days.whereType<Map>()) {
      final day = Map<String, dynamic>.from(raw);
      if (day['date']?.toString() == targetKey) {
        selected = day;
        break;
      }
    }
    if (selected == null) return null;

    final rawPoints = selected['points'];
    final points = <WeatherPoint>[];
    if (rawPoints is List) {
      final rows = rawPoints.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList(growable: false);
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final min = _number(row['tempMin']);
        final max = _number(row['tempMax']);
        final temperature = min != null && max != null ? (min + max) / 2 : (max ?? min ?? 0);
        points.add(WeatherPoint(
          label: _routeLabel(i, rows.length),
          temperature: temperature,
          wind: _number(row['windMax']) ?? 0,
          precipitation: _number(row['precipMm']) ?? 0,
          tempMin: min,
          tempMax: max,
          symbolCode: row['symbolCode']?.toString() ?? '',
          lon: _number(row['lon']),
          lat: _number(row['lat']),
        ));
      }
    }
    if (points.isEmpty) return null;
    return TripWeatherDay(
      date: DateTime(targetDate.year, targetDate.month, targetDate.day),
      points: points,
      provider: data['provider']?.toString() ?? '',
      providerLabel: data['providerLabel']?.toString() ?? '',
      generatedAt: DateTime.tryParse(data['generatedAt']?.toString() ?? ''),
    );
  }

  static bool withinForecastWindow(DateTime tripDate, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(tripDate.year, tripDate.month, tripDate.day);
    final offset = target.difference(today).inDays;
    return offset >= 0 && offset <= 8;
  }

  static int daysToRequest(DateTime tripDate, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(tripDate.year, tripDate.month, tripDate.day);
    final offset = target.difference(today).inDays;
    final requested = offset + 1;
    if (requested < 1) return 1;
    if (requested > 9) return 9;
    return requested;
  }

  static String _routeLabel(int index, int length) {
    if (index == 0) return 'Start';
    if (index == length - 1) return 'Mål';
    return 'Rute ${index + 1}';
  }

  static double? _number(Object? raw) => raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');

  static String _dateKey(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
