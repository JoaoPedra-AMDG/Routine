import 'dart:io';
import 'package:flutter/services.dart';

const channel = MethodChannel('za.co.joaopedra.daybook/storage');
File get dataFile {
  final env = Platform.environment;
  final base =
      Platform.isWindows
          ? (env['APPDATA'] ?? env['USERPROFILE'] ?? Directory.current.path)
          : Platform.isMacOS
          ? '${env['HOME']}/Library/Application Support'
          : env['XDG_DATA_HOME'] ?? '${env['HOME']}/.local/share';
  return File('$base/Daybook/schedule.json');
}

Future<String?> loadSchedule() async {
  if (Platform.isAndroid || Platform.isIOS) {
    return channel.invokeMethod<String>('load');
  }
  final file = dataFile;
  return await file.exists() ? file.readAsString() : null;
}

Future<void> saveSchedule(String text) async {
  if (Platform.isAndroid || Platform.isIOS) {
    await channel.invokeMethod<void>('save', text);
    return;
  }
  final file = dataFile;
  await file.parent.create(recursive: true);
  final temp = File('${file.path}.tmp');
  await temp.writeAsString(text, flush: true);
  await temp.rename(file.path);
}
