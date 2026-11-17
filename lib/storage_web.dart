import 'package:web/web.dart' as web;

Future<String?> loadSchedule() async =>
    web.window.localStorage.getItem('daybook.v1');
Future<void> saveSchedule(String text) async {
  web.window.localStorage.setItem('daybook.v1', text);
}
