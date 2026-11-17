import 'package:flutter/material.dart';
import 'schedule.dart';
import 'storage.dart';
import 'routine_app.dart';
import 'web_shell_stub.dart' if (dart.library.js_interop) 'web_shell_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Schedule schedule;
  String? error;
  try {
    final data = await loadSchedule();
    schedule = data == null ? Schedule.seed() : Schedule.decode(data);
  } catch (_) {
    schedule = Schedule.seed();
    error =
        'Saved plans could not be read. Restore a backup before changing plans.';
  }
  prepareShell();
  runApp(RoutineApp(schedule: schedule, storageError: error));
}
