import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile settings are account-backed and editable', () {
    final state = File('lib/app/app_state.dart').readAsStringSync();
    final profile = File('lib/features/profile/presentation/profile_screen.dart').readAsStringSync();
    final auth = File('lib/features/auth/auth_service.dart').readAsStringSync();

    expect(state, contains("api.domain('profile', 'getById'"));
    expect(state, contains("api.domain('profile', 'update'"));
    expect(state, contains("'preferred_transport_mode'"));
    expect(state, contains("'location_sharing'"));
    expect(profile, contains('Rediger profil'));
    expect(profile, contains('Offentlig profil'));
    expect(profile, contains('Tillat vurderinger'));
    expect(auth, contains("storage.from('profile-media').uploadBinary"));
  });

  test('history hydrates stages and persists completed status', () {
    final state = File('lib/app/app_state.dart').readAsStringSync();
    final history = File('lib/features/history/presentation/history_screen.dart').readAsStringSync();

    expect(state, contains("api.domain('stage', 'listForTrip'"));
    expect(state, contains('_stageFromLooseJson'));
    expect(state, contains("'pending_trip_status_updates'"));
    expect(state, contains("current['status'] = meta['status'] ?? 'Fullført'"));
    expect(state, contains("store.writeJson('completed_trip_snapshots'"));
    expect(state, contains('TripStatus.planned'));
    expect(history, contains('Planlagte turer'));
    expect(history, contains('Pågående turer'));
    expect(history, contains('Fullførte turer'));
    expect(history, contains('Arkiverte turer'));
    expect(history, contains('Lagrede community-ruter og kataloginnhold legges ikke automatisk i historikken.'));
  });
}
