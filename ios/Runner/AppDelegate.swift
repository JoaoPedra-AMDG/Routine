import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "za.co.joaopedra.daybook/storage", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "load": result(UserDefaults.standard.string(forKey: "routine_schedule"))
        case "save":
          guard let value = call.arguments as? String else {
            result(FlutterError(code: "invalid", message: "Invalid schedule", details: nil))
            return
          }
          UserDefaults.standard.set(value, forKey: "routine_schedule")
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
