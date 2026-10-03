import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/core/display/phone_speed_warning.dart';

void main() {
  final now = DateTime.utc(2026, 10, 3);
  bool warning({bool enabled = true, bool navigating = true, String quality = 'GOOD',
    double? speed = 15, int? limit = 50, double? accuracy = 5, int age = 0}) =>
    phoneSpeedWarning(enabled: enabled, navigating: navigating, gpsQuality: quality,
      speedMetersPerSecond: speed, speedLimitKph: limit, accuracyMeters: accuracy,
      sampleTime: now.subtract(Duration(seconds: age)), now: now);

  test('unrounded speed must exceed a known positive limit', () {
    expect(warning(), isTrue);
    expect(warning(speed: 10, limit: 36), isFalse);
    expect(warning(speed: 10.01, limit: 36), isTrue);
    expect(warning(limit: null), isFalse);
    expect(warning(limit: 0), isFalse);
    expect(warning(speed: null), isFalse);
    expect(warning(speed: -1), isFalse);
    expect(warning(speed: double.nan), isFalse);
    expect(warning(speed: double.infinity), isFalse);
  });
  test('disabled, inactive, inaccurate or stale samples cannot warn', () {
    expect(warning(enabled: false), isFalse);
    expect(warning(navigating: false), isFalse);
    expect(warning(quality: 'POOR'), isFalse);
    expect(warning(quality: 'unknown'), isFalse);
    expect(warning(accuracy: 26), isFalse);
    expect(warning(accuracy: double.nan), isFalse);
    expect(warning(age: 11), isFalse);
    expect(warning(age: -1), isFalse);
    expect(warning(age: 10, accuracy: 25), isTrue);
  });
}
