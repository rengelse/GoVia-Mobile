import 'package:flutter_test/flutter_test.dart';
import 'package:govia_mobile/domain/models.dart';

void main() {
  test('transport labels are stable', () {
    expect(transportLabel(StageTransport.motorcycle), 'Motorsykkel');
    expect(transportLabel(StageTransport.ferry), 'Ferge');
  });

  test('stage sort is day then order', () {
    final stages = [
      const Stage(id: 'c', day: 2, order: 0, start: 'C', end: 'D', transport: StageTransport.motorcycle),
      const Stage(id: 'b', day: 1, order: 1, start: 'B', end: 'C', transport: StageTransport.ferry),
      const Stage(id: 'a', day: 1, order: 0, start: 'A', end: 'B', transport: StageTransport.motorcycle),
    ]..sort((a, b) => a.day != b.day ? a.day.compareTo(b.day) : a.order.compareTo(b.order));
    expect(stages.map((e) => e.id), ['a', 'b', 'c']);
  });
}
