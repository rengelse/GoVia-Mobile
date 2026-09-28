import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phone and Android Auto Photon search use supported language negotiation', () {
    final phone = File('lib/features/new_trip/presentation/plan_trip_screen.dart').readAsStringSync();
    final car = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarSearchScreen.kt').readAsStringSync();
    expect(phone, contains("photon.komoot.io"));
    expect(car, contains('photon.komoot.io'));
    expect(phone, isNot(contains("'lang': 'no'")));
    expect(car, isNot(contains('lang=no')));
    expect(phone, contains('Accept-Language'));
    expect(car, contains('Accept-Language'));
  });
}
