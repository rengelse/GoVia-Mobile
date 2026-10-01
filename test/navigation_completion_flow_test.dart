import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('navigation has explicit stop and completion choices', () {
    final source = File('lib/features/navigation/presentation/navigation_screen.dart').readAsStringSync();
    expect(source, contains("'Avslutt navigasjon'"));
    expect(source, contains("'Fullfør'"));
    expect(source, contains("'Behold ruten åpen'"));
    expect(source, contains('_handleArrival()'));
  });

  test('navigation language setting is persisted and synced to car', () {
    final state = File('lib/app/app_state.dart').readAsStringSync();
    final profile = File('lib/features/profile/presentation/profile_screen.dart').readAsStringSync();
    expect(state, contains('navigation_language'));
    expect(state, contains("'navigationLanguage': navigationLanguage"));
    expect(profile, contains("'Navigasjonsspråk'"));
  });
}
