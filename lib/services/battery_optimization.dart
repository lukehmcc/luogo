import 'package:flutter/services.dart';
import 'package:luogo/main.dart';

/// Platform access for Android's per-app battery optimization ("Unrestricted").
///
/// On non-Android platforms [isExempt] reports `true` so the UI can hide the
/// banner; [requestExemption] is a no-op there.
class BatteryOptimizationService {
  static const MethodChannel _channel =
      MethodChannel('app.luogo.app/battery_optimization');

  /// Whether the app is currently exempt from battery optimization.
  static Future<bool> isExempt() async {
    try {
      final dynamic result =
          await _channel.invokeMethod('isIgnoringBatteryOptimizations');
      return result is bool && result;
    } catch (e) {
      logger.d("isIgnoringBatteryOptimizations failed: $e");
      // Assume exempt so we don't nag when the platform can't tell us.
      return true;
    }
  }

  /// Opens the Android prompt to whitelist the app against battery
  /// optimization. No-op on platforms without the concept.
  static Future<void> requestExemption() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      logger.d("requestIgnoreBatteryOptimizations failed: $e");
    }
  }
}
