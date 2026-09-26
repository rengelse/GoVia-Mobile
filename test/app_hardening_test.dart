import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/core/config/app_config.dart';

void main() {
  test('production Supabase config matches GoVia Desktop project', () {
    expect(AppConfig.hasSupabase, isTrue);
    expect(AppConfig.supabaseUrl, 'https://pzhtlbquwvdrqqxrvhct.supabase.co');
    expect(AppConfig.supabaseClientKey, startsWith('sb_publishable_'));
  });

  test('login cannot reveal shell through initialRoute stack', () {
    final app = File('lib/app/govia_app.dart').readAsStringSync();
    expect(app, isNot(contains('initialRoute:')));
    expect(app, contains('home: state.signedIn ? const ShellScreen() : const LoginScreen()'));
    expect(app, contains("if (!state.signedIn && !wantsLogin)"));
  });

  test('history has no production dummy trips', () {
    final history = File('lib/features/history/presentation/history_screen.dart').readAsStringSync();
    expect(history, isNot(contains('Vestland rundt')));
    expect(history, isNot(contains('Sørlandet')));
    expect(history, isNot(contains('Jæren søndagstur')));
  });

  test('release workflow cannot erase built-in Supabase config with empty secrets', () {
    final workflow = File('.github/workflows/android-release.yml').readAsStringSync();
    expect(workflow, isNot(contains('--dart-define=SUPABASE_URL')));
    expect(workflow, isNot(contains('--dart-define=SUPABASE_ANON_KEY')));
  });
}
