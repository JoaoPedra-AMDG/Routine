import 'dart:js_interop';
import 'package:web/web.dart' as web;

void prepareShell() {
  web.document.getElementById('loading')?.remove();
}

bool get supportsInstallation => true;
@JS('requestRoutineInstall')
external JSPromise<JSString> _requestInstall();
Future<String> installApp() async => (await _requestInstall().toDart).toDart;

@JS('prepareRoutineOffline')
external JSPromise<JSBoolean> _prepareOffline(JSBoolean retry);
Future<bool> prepareOffline({bool retry = false}) async =>
    (await _prepareOffline(retry.toJS).toDart).toDart;
