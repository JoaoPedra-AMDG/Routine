import 'storage_stub.dart'
    if (dart.library.io) 'storage_io.dart'
    if (dart.library.js_interop) 'storage_web.dart'
    as backend;

Future<String?> loadSchedule() => backend.loadSchedule();
Future<void> saveSchedule(String text) => backend.saveSchedule(text);
