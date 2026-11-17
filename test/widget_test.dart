import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daybook/routine_app.dart';
import 'package:daybook/schedule.dart';

void main() {
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
      RoutineApp(schedule: Schedule.seed(), writer: (_) async {}),
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
