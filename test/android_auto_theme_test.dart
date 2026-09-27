import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Auto theme offers automatic, light and dark modes', () {
    final profile = File('lib/features/profile/presentation/profile_screen.dart').readAsStringSync();
    final state = File('lib/app/app_state.dart').readAsStringSync();
    expect(profile, contains("'system': 'Automatisk'"));
    expect(profile, contains("'light': 'Lys'"));
    expect(profile, contains("'dark': 'Mørk'"));
    expect(state, contains("store.writeString('android_auto_theme_mode', mode)"));
    expect(state, contains("'themeMode': androidAutoThemeMode"));
  });

  test('automatic mode follows host and switches real day and dark map styles', () {
    final navigation = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarNavigationScreen.kt').readAsStringSync();
    final surface = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarMapSurface.kt').readAsStringSync();
    expect(navigation, contains('Configuration.UI_MODE_NIGHT_MASK'));
    expect(navigation, contains('"light" -> false'));
    expect(navigation, contains('"dark" -> true'));
    expect(surface, contains('LIGHT_STYLE'));
    expect(surface, contains('DARK_STYLE'));
    expect(surface, contains('styles/liberty'));
    expect(surface, contains('styles/dark'));
    expect(surface, contains('val style = if (darkMode) DARK_STYLE else LIGHT_STYLE'));
    expect(surface, contains('NIGHT_LIFT'));
  });
}
