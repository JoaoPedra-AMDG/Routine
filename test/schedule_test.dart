import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:daybook/schedule.dart';

void main() {
  test('daily view defaults to checklist and survives saved settings', () {
    final schedule = Schedule.seed();
    expect(schedule.showTimetable, false);
    schedule.showTimetable = true;
    expect(Schedule.decode(schedule.encode()).showTimetable, true);
    final older = jsonDecode(schedule.encode()) as Map<String, dynamic>;
    (older['settings'] as Map).remove('showTimetable');
    expect(Schedule.decode(jsonEncode(older)).showTimetable, false);
    (older['settings'] as Map)['showTimetable'] = 'yes';
    expect(() => Schedule.decode(jsonEncode(older)), throwsFormatException);
  });
  test(
    'brief preparation is two hours tomorrow with Thursday Wits-vendor deadline',
    () {
      final schedule = Schedule.seed();
      final tomorrow = schedule.on('2026-11-18');
      final brief = tomorrow.firstWhere(
        (p) => p.id == 'project-briefs-work-2026-11-18',
      );
      expect(brief.isTask, true);
      expect(brief.start, 900);
      expect(brief.end - brief.start, 120);
      expect(schedule.overlaps(brief, tomorrow), isEmpty);
      expect(brief.notes, contains('Wits vendors'));
      expect(schedule.on('2026-11-19').any((p) => p.id == brief.id), false);
      final deadline = schedule
          .on('2026-11-19')
          .firstWhere((p) => p.id == 'project-briefs-due-2026-11-19');
      expect(deadline.allDay, true);
      expect(deadline.notes, contains('BOM'));
      final fhs = schedule
          .on('2026-11-24')
          .firstWhere((p) => p.id == 'fhs-exhibition-2026-11-24');
      expect(fhs.category, 'uni');
      expect(fhs.title, contains('provisional'));
      expect(fhs.allDay, true);
      expect(fhs.timeTbc, true);
    },
  );
  test(
    'Science Forum details update existing entries without duplicating or losing edits',
    () {
      final old = Schedule.seed().toJson();
      final newIds = {
        'project-briefs-work-2026-11-18',
        'project-briefs-due-2026-11-19',
        'fhs-exhibition-2026-11-24',
      };
      (old['appliedEventUpdates'] as List).removeWhere(
        (id) => newIds.contains(id) || id == 'sfsa-2026-details-v1',
      );
      final items = old['items'] as List;
      items.removeWhere(
        (p) => newIds.contains(p['id']) || p['id'] == 'ev-close',
      );
      final opening = items.firstWhere((p) => p['id'] == 'ev-opening');
      opening['title'] = 'EV presentation: opening';
      opening['category'] = 'work';
      opening['notes'] = 'My go-kart preparation notes';
      items.firstWhere((p) => p['id'] == 'ev-reception')['title'] =
          'My reception plan';
      old['overrides'] = {
        '2026-12-01|ev-opening': {'start': '15:30', 'end': '18:30'},
      };
      final updated = Schedule.decode(jsonEncode(old));
      final forumOpening = updated
          .on('2026-12-01')
          .firstWhere((p) => p.id == 'ev-opening');
      expect(forumOpening.title, 'Science Forum: opening');
      expect(forumOpening.category, 'uni');
      expect(forumOpening.start, 930);
      expect(
        forumOpening.notes,
        contains('CSIR International Convention Centre'),
      );
      expect(forumOpening.notes, contains('My go-kart preparation notes'));
      expect(
        updated.items.firstWhere((p) => p.id == 'ev-reception').title,
        'My reception plan',
      );
      expect(updated.items.any((p) => p.id == 'ev-close'), false);
      expect(updated.items.where((p) => p.id == 'ev-opening').length, 1);
      final restored = Schedule.decode(updated.encode());
      expect(
        restored.items.firstWhere((p) => p.id == 'ev-opening').notes,
        forumOpening.notes,
      );
      expect(restored.items.where((p) => newIds.contains(p.id)).length, 3);
    },
  );
  test('new trips include both dates and stay outside the timetable', () {
    final schedule = Schedule.seed();
    for (final day in [
      '2026-11-19',
      '2026-11-20',
      '2026-11-21',
      '2026-11-22',
    ]) {
      final trip = schedule
          .on(day)
          .firstWhere((p) => p.id == 'vall-friends-2026-11-19');
      expect(trip.allDay, true);
      expect(trip.category, 'friends');
    }
    expect(
      schedule.on('2026-11-18').any((p) => p.id == 'vall-friends-2026-11-19'),
      false,
    );
    expect(
      schedule.on('2026-11-23').any((p) => p.id == 'vall-friends-2026-11-19'),
      false,
    );
    for (final day in [
      '2026-11-25',
      '2026-11-26',
      '2026-11-27',
      '2026-11-28',
      '2026-11-29',
    ]) {
      final camp = schedule
          .on(day)
          .firstWhere((p) => p.id == 'community-service-camp-2026');
      expect(camp.allDay, true);
      expect(camp.category, 'catholic');
      expect(camp.notes, contains('R800'));
    }
    expect(
      schedule
          .on('2026-11-30')
          .any((p) => p.id == 'community-service-camp-2026'),
      false,
    );
  });
  test(
    'existing installs receive events once and retain edits, removals and checkmarks',
    () {
      final old = Schedule.seed().toJson()..remove('appliedEventUpdates');
      (old['items'] as List).removeWhere(
        (p) => [
          'community-service-camp-2026',
          'vall-friends-2026-11-19',
        ].contains(p['id']),
      );
      old['overrides'] = {
        '2026-11-17|mass': {'status': 'done', 'start': '08:00', 'end': '08:30'},
      };
      final updated = Schedule.decode(jsonEncode(old));
      expect(updated.items.length, 25);
      expect(
        updated.on('2026-11-17').firstWhere((p) => p.id == 'mass').status,
        'done',
      );
      expect(
        updated.on('2026-11-17').firstWhere((p) => p.id == 'mass').start,
        480,
      );
      updated.applyEventUpdates();
      expect(updated.items.length, 25);
      final trip = updated.items.firstWhere(
        (p) => p.id == 'vall-friends-2026-11-19',
      );
      updated.items[updated.items.indexOf(trip)] = trip.withChanges({
        'notes': 'Return on Sunday afternoon',
      });
      updated.items.removeWhere((p) => p.id == 'community-service-camp-2026');
      final restored = Schedule.decode(updated.encode());
      expect(
        restored.items.any((p) => p.id == 'community-service-camp-2026'),
        false,
      );
      expect(
        restored.items
            .firstWhere((p) => p.id == 'vall-friends-2026-11-19')
            .notes,
        'Return on Sunday afternoon',
      );
      expect(
        restored.items.where((p) => p.id == 'vall-friends-2026-11-19').length,
        1,
      );
    },
  );
  test(
    'legacy activity types migrate without losing day changes or settings',
    () {
      final json = Schedule.seed().toJson();
      for (final item in json['items'] as List) {
        if (item['category'] == 'catholic') item['category'] = 'prayer';
        if (item['category'] == 'exercise') item['category'] = 'wellbeing';
        if (item['id'] == 'gianna') item['category'] = 'learning';
      }
      (json['items'] as List).add({
        ...const Plan(
          id: 'lecture',
          title: 'Lecture',
          date: '2026-11-17',
          category: 'uni',
        ).toJson(),
        'category': 'learning',
      });
      json['settings'] = {'showRecurringEventsInMonth': false};
      json['overrides'] = {
        '2026-11-17|mass': {
          'category': 'prayer',
          'status': 'done',
          'start': '08:00',
          'end': '08:30',
        },
        '2026-11-17|jog': {'category': 'wellbeing', 'status': 'skipped'},
        '2026-11-17|gianna': {'category': 'learning', 'notes': 'Lesson notes'},
      };
      final restored = Schedule.decode(jsonEncode(json));
      final day = restored.on('2026-11-17');
      final mass = day.firstWhere((p) => p.id == 'mass');
      expect(mass.category, 'catholic');
      expect(mass.status, 'done');
      expect(mass.start, 480);
      expect(day.firstWhere((p) => p.id == 'jog').category, 'exercise');
      expect(day.firstWhere((p) => p.id == 'jog').status, 'skipped');
      expect(day.firstWhere((p) => p.id == 'gianna').category, 'family');
      expect(day.firstWhere((p) => p.id == 'gianna').notes, 'Lesson notes');
      expect(day.firstWhere((p) => p.id == 'lecture').category, 'uni');
      expect(restored.overrides['2026-11-17|mass']!['category'], 'catholic');
      expect(restored.showRecurringEventsInMonth, false);
      expect(Schedule.decode(restored.encode()).items.length, 26);
    },
  );
  test(
    'month visibility preference survives backups and defaults on for older data',
    () {
      final schedule = Schedule.seed()..showRecurringEventsInMonth = false;
      expect(
        Schedule.decode(schedule.encode()).showRecurringEventsInMonth,
        false,
      );
      final old = schedule.toJson()..remove('settings');
      expect(Schedule.decode(jsonEncode(old)).showRecurringEventsInMonth, true);
      final invalid =
          schedule.toJson()
            ..['settings'] = {'showRecurringEventsInMonth': 'false'};
      expect(() => Schedule.decode(jsonEncode(invalid)), throwsFormatException);
    },
  );
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
      expect(restored.items.length, 25);
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
