// Legacy development entrypoint kept temporarily for backwards compatibility.
// Normal development now uses lib/main.dart; the simulator is exposed from
// Profil -> Utviklerverktøy only in debug builds.
import 'main.dart' as production;

Future<void> main() => production.main();
