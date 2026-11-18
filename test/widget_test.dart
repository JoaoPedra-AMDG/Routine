import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daybook/routine_app.dart';
import 'package:daybook/schedule.dart';
import 'package:daybook/plan_editor.dart';

Future<void> swipeSchedule(WidgetTester tester, double distance) async {
  final area = tester.getRect(
    find.byKey(const ValueKey('schedule-swipe-area')),
  );
  await tester.dragFrom(
    Offset(area.center.dx, area.top + 100),
    Offset(distance, 0),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'settings sits after Add and saves the daily view without inline controls',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final saved = <String>[];
      await tester.pumpWidget(
        RoutineApp(
          schedule: Schedule.seed(),
          initialDate: parseDate('2026-11-17'),
          writer: (s) async {
            saved.add(s);
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Checklist'), findsOneWidget);
      expect(find.text('Timetable'), findsNothing);
      expect(
        tester.getCenter(find.byKey(const ValueKey('settings-button'))).dx,
        greaterThan(
          tester.getCenter(find.byKey(const ValueKey('add-plan-button'))).dx,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('settings-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('daily-view-setting')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timetable').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Timetable'), findsOneWidget);
      expect(find.text('Checklist'), findsNothing);
      expect(Schedule.decode(saved.last).showTimetable, true);
      await tester.pumpWidget(
        RoutineApp(
          key: UniqueKey(),
          schedule: Schedule.decode(saved.last),
          initialDate: parseDate('2026-11-17'),
          writer: (_) async {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Timetable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'horizontal swipes change days while vertical scrolling keeps the date',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        RoutineApp(
          schedule: Schedule.seed(),
          initialDate: parseDate('2026-11-17'),
          writer: (_) async {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Next day'), findsNothing);
      expect(find.byTooltip('Previous day'), findsNothing);
      await swipeSchedule(tester, -180);
      expect(find.text('18 November 2026'), findsOneWidget);
      await swipeSchedule(tester, 180);
      expect(find.text('17 November 2026'), findsOneWidget);
      await swipeSchedule(tester, 180);
      expect(find.text('16 November 2026'), findsOneWidget);
      final area = tester.getRect(
        find.byKey(const ValueKey('schedule-swipe-area')),
      );
      await tester.dragFrom(
        Offset(area.center.dx, area.top + 400),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      expect(find.text('16 November 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'timetable vertical drags reschedule and horizontal swipes change days',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final saved = <String>[];
      await tester.pumpWidget(
        RoutineApp(
          schedule: Schedule.seed()..showTimetable = true,
          initialDate: parseDate('2026-11-17'),
          writer: (s) async {
            saved.add(s);
          },
        ),
      );
      await tester.pumpAndSettle();
      final task = find.byTooltip(
        'Organize the house: 9am – 10am. Tap to move.',
      );
      final point = tester.getTopLeft(task) + const Offset(40, 6);
      await tester.dragFrom(point, const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(find.text('17 November 2026'), findsOneWidget);
      expect(
        Schedule.decode(
          saved.last,
        ).on('2026-11-17').firstWhere((p) => p.id == 'house').start,
        480,
      );
      final movedTask = find.byTooltip(
        'Organize the house: 8am – 9am. Tap to move.',
      );
      await tester.dragFrom(
        tester.getTopLeft(movedTask) + const Offset(40, 6),
        const Offset(-180, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('18 November 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'activity type picker offers the requested types and saves Friends',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PlanEdit? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await showDialog<PlanEdit>(
                        context: context,
                        builder:
                            (_) => PlanEditor(
                              day: parseDate('2026-11-17'),
                              event: true,
                            ),
                      );
                    },
                    child: const Text('New event'),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('New event'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Meet friends');
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      for (final label in [
        'Catholic',
        'Uni',
        'Family',
        'Friends',
        'Exercise',
      ]) {
        expect(find.text(label), findsWidgets);
      }
      await tester.tap(find.text('Friends').last);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(result?.plan.category, 'friends');
      expect(result?.plan.title, 'Meet friends');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'month filter persists and keeps one-off events and daily routines',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final saved = <String>[];
      final schedule =
          Schedule.seed()
            ..items.add(
              const Plan(
                id: 'meeting',
                title: 'Recurring meeting',
                date: '2026-12-01',
                kind: 'event',
                repeat: 'daily',
                category: 'work',
              ),
            );
      await tester.pumpWidget(
        RoutineApp(
          schedule: schedule,
          initialDate: parseDate('2026-12-01'),
          writer: (s) async {
            saved.add(s);
          },
        ),
      );
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      Finder inMonth(Finder matching) => find.descendant(
        of: find.byKey(const ValueKey('month-view')),
        matching: matching,
      );
      expect(inMonth(find.textContaining('Adoration')), findsWidgets);
      expect(inMonth(find.textContaining('Recurring meeting')), findsWidgets);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(inMonth(find.textContaining('Adoration')), findsNothing);
      expect(inMonth(find.textContaining('Recurring meeting')), findsNothing);
      expect(inMonth(find.textContaining('Grandparents arrive')), findsWidgets);
      expect(Schedule.decode(saved.last).showRecurringEventsInMonth, false);
      await tester.pumpWidget(
        RoutineApp(
          key: UniqueKey(),
          schedule: Schedule.decode(saved.last),
          initialDate: parseDate('2026-12-01'),
          writer: (_) async {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recurring meeting'), findsWidgets);
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, false);
      expect(inMonth(find.textContaining('Recurring meeting')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'date opens the picker for past and future dates and preserves month view',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        RoutineApp(
          schedule: Schedule.seed(),
          initialDate: parseDate('2026-11-17'),
          writer: (_) async {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsNothing);
      for (final day in [20, 11]) {
        await tester.tap(find.byKey(const ValueKey('date-picker-button')));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        await tester.tap(find.text('$day'));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.text('$day November 2026'), findsOneWidget);
      }
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('date-picker-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('18'),
        ),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Recurring events'), findsOneWidget);
      expect(find.text('November 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('confirming an event time reveals its time fields', (
    tester,
  ) async {
    final plan = Schedule.seed().items.firstWhere(
      (p) => p.id == 'confirmation',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanEditor(
            day: parseDate('2026-12-04'),
            original: plan,
            occurrence: plan,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final controls =
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .toList();
    expect(controls.first.value, false);
    expect(controls.last.value, true);
    await tester.tap(find.text('Time to confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Start time'), findsOneWidget);
    expect(find.text('End time'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('completing a task persists per day and navigation resets it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saved = <String>[];
    await tester.pumpWidget(
      RoutineApp(
        schedule: Schedule.seed(),
        initialDate: parseDate('2026-11-17'),
        writer: (s) async {
          saved.add(s);
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final check = find.byType(Checkbox).first;
    await tester.tap(check);
    await tester.pumpAndSettle();
    expect(find.text('1 of 10 complete'), findsOneWidget);
    expect(saved, isNotEmpty);
    await swipeSchedule(tester, -180);
    expect(find.text('0 of 12 complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('phone day, calendar and editor fit without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RoutineApp(
        schedule: Schedule.seed(),
        initialDate: parseDate('2026-11-17'),
        writer: (_) async {},
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Add').first);
    await tester.pumpAndSettle();
    expect(find.text('Add plan'), findsOneWidget);
    expect(find.text('Repeat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
