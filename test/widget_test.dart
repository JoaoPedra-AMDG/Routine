import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daybook/routine_app.dart';
import 'package:daybook/schedule.dart';
import 'package:daybook/plan_editor.dart';

void main() {
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
    await tester.tap(find.byTooltip('Next day'));
    await tester.pumpAndSettle();
    expect(find.text('0 of 11 complete'), findsOneWidget);
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
