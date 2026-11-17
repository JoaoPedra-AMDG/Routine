import 'package:flutter_test/flutter_test.dart';
import 'package:daybook/schedule.dart';

void main() {
  test('completion and moves affect only the selected day', () {
    final s = Schedule.seed();
    expect(s.on('2026-11-17').where((p) => p.isTask).length, 10);
    s.changeDay('2026-11-17', 'mass', {
      'status': 'done',
      'start': '08:00',
      'end': '08:30',
    });
    expect(s.on('2026-11-17').firstWhere((p) => p.id == 'mass').status, 'done');
    final next = s.on('2026-11-18').firstWhere((p) => p.id == 'mass');
    expect(next.status, 'pending');
    expect(next.start, 390);
  });
  test('Wednesday and Friday commitments and Friday development', () {
    final s = Schedule.seed();
    expect(s.on('2026-11-18').any((p) => p.id == 'adoration-wed'), true);
    expect(s.on('2026-11-19').any((p) => p.id == 'adoration-wed'), false);
    final fri = s.on('2026-11-20');
    expect(fri.firstWhere((p) => p.id == 'direction').start, 870);
    expect(fri.firstWhere((p) => p.id == 'adoration-fri').end, 1020);
    final dev = fri.firstWhere((p) => p.id == 'development');
    expect(dev.end, 870);
    expect(s.overlaps(dev, fri), isEmpty);
  });
  test('jog shifts before EV opening but manual moves take precedence', () {
    final s = Schedule.seed();
    expect(s.on('2026-11-18').firstWhere((p) => p.id == 'jog').start, 1020);
    final day = s.on('2026-12-01'), jog = day.firstWhere((p) => p.id == 'jog');
    expect(jog.start, 930);
    expect(jog.end, 960);
    expect(s.overlaps(jog, day), isEmpty);
    s.changeDay('2026-12-01', 'jog', {'start': '08:00', 'end': '08:30'});
    expect(s.on('2026-12-01').firstWhere((p) => p.id == 'jog').start, 480);
  });
  test('jog finds a slot before chained conflicts', () {
    final s = Schedule.seed();
    s.items.add(
      const Plan(
        id: 'prep',
        title: 'Prep',
        date: '2026-12-01',
        start: 900,
        end: 960,
      ),
    );
    expect(s.on('2026-12-01').firstWhere((p) => p.id == 'jog').start, 810);
  });
  test('trip includes both boundary dates and stays above timetable', () {
    final s = Schedule.seed();
    for (final day in [
      '2026-11-28',
      '2026-11-29',
      '2026-11-30',
      '2026-12-01',
    ]) {
      expect(s.on(day).firstWhere((p) => p.id == 'sister-trip').allDay, true);
    }
    expect(s.on('2026-12-02').any((p) => p.id == 'sister-trip'), false);
  });
  test('December events and overlaps retain known and unconfirmed times', () {
    final s = Schedule.seed(), day = s.on('2026-12-01');
    expect(day.firstWhere((p) => p.id == 'ev-opening').start, 960);
    expect(day.firstWhere((p) => p.id == 'ev-reception').end, 1290);
    expect(
      s.on('2026-12-02').firstWhere((p) => p.id == 'ev-days').timeTbc,
      true,
    );
    expect(
      s.on('2026-12-03').firstWhere((p) => p.id == 'ev-days').allDay,
      true,
    );
    expect(
      s.on('2026-12-04').firstWhere((p) => p.id == 'confirmation').timeTbc,
      true,
    );
    expect(
      s.on('2026-12-04').firstWhere((p) => p.id == 'ev-close').allDay,
      true,
    );
    expect(
      s
          .overlaps(day.firstWhere((p) => p.id == 'rosary'), day)
          .any((p) => p.id == 'ev-reception'),
      true,
    );
  });
  test('skip and removal are scoped to one date', () {
    final s = Schedule.seed();
    s.changeDay('2026-11-17', 'mass', {'status': 'skipped'});
    expect(
      s.on('2026-11-18').firstWhere((p) => p.id == 'mass').status,
      'pending',
    );
    s.changeDay('2026-11-17', 'mass', {'deleted': true});
    expect(s.on('2026-11-17').any((p) => p.id == 'mass'), false);
    expect(s.on('2026-11-18').any((p) => p.id == 'mass'), true);
  });
  test('new weekly routines respect bounds and weekdays', () {
    const p = Plan(
      id: 'weekly',
      title: 'Weekly',
      date: '2026-11-17',
      repeat: 'weekly',
      weekdays: [2],
      until: '2026-12-01',
    );
    expect(p.occurs('2026-11-10'), false);
    expect(p.occurs('2026-11-24'), true);
    expect(p.occurs('2026-12-01'), true);
    expect(p.occurs('2026-12-08'), false);
  });
  test(
    'backup round trip preserves plans and overrides and validates schema',
    () {
      final s = Schedule.seed();
      s.changeDay('2026-11-17', 'mass', {'status': 'done'});
      final restored = Schedule.decode(s.encode());
      expect(
        restored.on('2026-11-17').firstWhere((p) => p.id == 'mass').status,
        'done',
      );
      expect(restored.items.length, 20);
      expect(
        () => Schedule.decode(s.encode().replaceFirst('06:00', '99:00')),
        throwsFormatException,
      );
      expect(
        () => Schedule.decode(
          s.encode().replaceFirst('2026-11-17', '2026-02-31'),
        ),
        throwsFormatException,
      );
      expect(() => Schedule.decode('{"version":2}'), throwsFormatException);
    },
  );
}
