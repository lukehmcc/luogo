import Flutter
import UIKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  private var channel: FlutterMethodChannel?
  private let locationManager = CLLocationManager()
  private var handlerReady = false
  private var pendingLocations: [CLLocation] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let messenger = controller.binaryMessenger
      let channel = FlutterMethodChannel(
        name: "app.luogo.app/significant_location",
        binaryMessenger: messenger
      )
      channel.setMethodCallHandler { [weak self] call, _ in
        if call.method == "ready" {
          self?.handlerReady = true
          let pending = self?.pendingLocations ?? []
          self?.pendingLocations.removeAll()
          for location in pending {
            self?.sendSignificantChange(location)
          }
        }
      }
      self.channel = channel
    }

    locationManager.delegate = self
    if locationManager.authorizationStatus == .authorizedAlways {
      startMonitoring()
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func startMonitoring() {
    locationManager.startMonitoringSignificantLocationChanges()
  }

  private func sendSignificantChange(_ location: CLLocation) {
    channel?.invokeMethod("onSignificantChange", arguments: [
      "lat": location.coordinate.latitude,
      "lng": location.coordinate.longitude,
    ])
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .authorizedAlways:
      startMonitoring()
    default:
      manager.stopMonitoringSignificantLocationChanges()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    if handlerReady {
      sendSignificantChange(location)
    } else {
      pendingLocations.append(location)
    }
  }
}
