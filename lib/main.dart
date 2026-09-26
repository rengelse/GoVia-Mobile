import 'package:flutter/material.dart';
import 'app/app_state.dart';
import 'app/govia_app.dart';
import 'core/network/api_client.dart';
import 'core/storage/local_store.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = await AuthService.create();
  final store = await LocalStore.create();
  late final ApiClient api;
  api = ApiClient(accessTokenProvider: auth.accessToken);
  final state = AppState(auth: auth, api: api, store: store);
  await state.initialize();
  runApp(GoViaApp(state: state));
}
