import 'dart:js_interop';
import 'package:web/web.dart' as web;

void prepareShell() {
  web.document.getElementById('loading')?.remove();
}

bool get supportsInstallation => true;
@JS('requestRoutineInstall')
external JSPromise<JSString> _requestInstall();
Future<String> installApp() async => (await _requestInstall().toDart).toDart;
