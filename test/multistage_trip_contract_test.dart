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

  test('stage copy keeps identity and metadata when runtime status changes', () {
    const stage = Stage(
      id: 'stage-3',
      day: 3,
      order: 1,
      name: 'Fjell',
      start: 'A',
      end: 'B',
      transport: StageTransport.car,
      waypoints: [StageWaypoint(id: 'poi', name: 'Utsikt', kind: StageWaypointKind.poi)],
    );
    final active = stage.copyWith(status: StageStatus.active);
    expect(active.id, stage.id);
    expect(active.name, stage.name);
    expect(active.waypoints, stage.waypoints);
    expect(active.status, StageStatus.active);
  });
}
