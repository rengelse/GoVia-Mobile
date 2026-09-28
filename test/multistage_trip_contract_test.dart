import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';

void main() {
  test('stage model carries status and imported route waypoints', () {
    const stage = Stage(
      id: 'stage-2',
      day: 2,
      order: 0,
      name: 'Kystetappen',
      status: StageStatus.active,
      start: 'A',
      end: 'B',
      transport: StageTransport.motorcycle,
      waypoints: [
        StageWaypoint(id: 'via-1', name: 'Via', kind: StageWaypointKind.via),
        StageWaypoint(id: 'stop-1', name: 'Kafé', kind: StageWaypointKind.stop),
        StageWaypoint(id: 'poi-1', name: 'Utsikt', kind: StageWaypointKind.poi, category: 'Utsikt'),
      ],
    );
    expect(stage.status, StageStatus.active);
    expect(stage.viaPoints.length, 1);
    expect(stage.stops.length, 1);
    expect(stage.pois.single.name, 'Utsikt');
  });

  test('handoff accepts canonical nested stages and preserves stage-owned data', () {
    final state = File('lib/app/app_state.dart').readAsStringSync();
    expect(state, contains("final nestedTripStages = tripRaw['stages'];"));
    expect(state, contains("json['waypoints']"));
    expect(state, contains("json['stops']"));
    expect(state, contains("json['pois']"));
    expect(state, contains('routeCandidates'));
    expect(state, contains('routeProfile'));
    expect(state, contains('routePreferences'));
  });

  test('mobile can start an arbitrary stage and persists stage progress', () {
    final state = File('lib/app/app_state.dart').readAsStringSync();
    final stages = File('lib/features/trips/presentation/stages_screen.dart').readAsStringSync();
    expect(state, contains("store.writeString('active_stage_id_\${active.id}', stage.id)"));
    expect(state, contains('item.copyWith(status: StageStatus.completed)'));
    expect(stages, contains('startNavigationStage(stage)'));
    expect(stages, contains("'Start etappe'"));
    expect(stages, contains("'Kjør igjen'"));
  });

  test('android auto exposes stage selection and navigates only selected stage', () {
    final detail = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarTripDetailScreen.kt').readAsStringSync();
    final picker = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarStageSelectionScreen.kt').readAsStringSync();
    final models = File('android/app/src/main/kotlin/no/govia/mobile/car/GoViaCarModels.kt').readAsStringSync();
    expect(detail, contains('GoViaCarStageSelectionScreen'));
    expect(picker, contains('stages = listOf(stage)'));
    expect(picker, contains('GoViaCarNavigationScreen'));
    expect(models, contains('val waypoints: List<CarWaypoint>'));
  });
}
