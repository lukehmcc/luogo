import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "luogo background location ping")
    WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "app.luogo.app.iOSBackgroundAppRefresh", frequency: NSNumber(value: 20 * 60))
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
