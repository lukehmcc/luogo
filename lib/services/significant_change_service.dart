import 'dart:async';

import 'package:flutter/services.dart';
import 'package:luogo/services/background_sync_service.dart';

/// iOS-only conduit for significant location changes. When CoreLocation
/// wakes the app on meaningful movement, the native side invokes
/// [onSignificantChange], which runs the same relay sync as the periodic
/// background fetch but labels it "significant" so the Nerd Stats page can
/// tell the two apart.
class SignificantChangeService {
  static const MethodChannel _channel =
      MethodChannel('app.luogo.app/significant_location');

  static Future<void> register() async {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onSignificantChange') {
        unawaited(BackgroundSyncService.runRelaySync(source: 'significant'));
      }
    });
    // Tell the native side our handler is live so events that arrived during
    // cold launch are flushed instead of dropped. Non-iOS platforms have no
    // native implementation; MissingPluginException is expected and ignored.
    try {
      await _channel.invokeMethod('ready');
    } catch (e) {
      // Platform without the native channel — periodic sync still covers us.
    }
  }
}