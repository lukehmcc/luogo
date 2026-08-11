import 'dart:async';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:luogo/cubit/home/settings/settings_state.dart';
import 'package:luogo/main.dart';
import 'package:luogo/services/battery_optimization.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/services/relay_client.dart';
import 'package:luogo/services/relay_health.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which relay-probe stage the settings screen is currently in.
enum _ServerProbe { initial, checking, online, offline, mismatch }

/// A Cubit class for managing the settings state.
///
/// Probes the relay URL live as the user types: a reachable server gets
/// saved and the running relay client rebinds to it immediately. Also owns
/// the background/battery status so Settings stays widget-free.
class SettingsCubit extends Cubit<SettingsState> {
  SharedPreferencesWithCache prefs;
  SettingsCubit({
    required this.prefs,
  }) : super(const SettingsInitial()) {
    _lifecycleListener =
        AppLifecycleListener(onResume: () => refreshBattery());

    String? serverUrl = prefs.getString('server-url');
    if (serverUrl != null) {
      controller.text = serverUrl;
    }
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      String v = packageInfo.version;
      String b = packageInfo.buildNumber;
      version = "version $v+$b";
      emit(state);
    });
    controller.addListener(_onUrlChanged);
    // Show the status of the saved server as soon as Settings opens.
    if (controller.text.trim().isNotEmpty) {
      _scheduleProbe();
    }
    // Surface the current scheduling/battery status right away.
    refreshBackgroundStatus();
    refreshBattery();
  }

  late final AppLifecycleListener _lifecycleListener;

  TextEditingController controller = TextEditingController();
  String version = "";

  // Current probe stage + server protocol version, for state rebuilds.
  _ServerProbe _probe = _ServerProbe.initial;
  int _serverVersion = 0;

  // Non-server status fields.
  bool _batteryExempt = false;
  int _backgroundFetchStatus = -1;
  String? _lastSync;
  bool _checkingBackground = false;

  // Debounce typing: one cheap /api/health fetch per pause in typing.
  static const Duration _probeDebounce = Duration(milliseconds: 500);
  Timer? _debounce;
  // Stale-probe guard: only the latest probe may emit.
  int _probeSeq = 0;

  void _onUrlChanged() => _scheduleProbe();

  void _scheduleProbe() {
    _debounce?.cancel();
    final String url = controller.text.trim();
    if (url.isEmpty) {
      _probeSeq++; // invalidate in-flight probes
      _probe = _ServerProbe.initial;
      emitIfOpen(_currentState());
      return;
    }
    _probe = _ServerProbe.checking;
    emitIfOpen(_currentState());
    _debounce = Timer(_probeDebounce, () => _probeUrl(url));
  }

  // Probes GET /api/health on the candidate URL. On success the URL is saved
  // as the active relay and the running client rebinds immediately. A relay
  // speaking a different protocol version is rejected without rebinding.
  Future<void> _probeUrl(String url) async {
    final int seq = ++_probeSeq;
    final Uri? parsed = Uri.tryParse(url);
    if (parsed == null ||
        (parsed.scheme != 'http' &&
            parsed.scheme != 'https' &&
            parsed.scheme != 'wss')) {
      _probe = _ServerProbe.offline;
      emitIfOpen(_currentState());
      return;
    }
    final String normalized = normalizeRelayUrl(url);
    final RelayProbeResult result = await probeRelayHealth(normalized);
    if (seq != _probeSeq || isClosed) return; // superseded
    switch (result.status) {
      case RelayProbeStatus.online:
        await prefs.setString('server-url', normalized);
        await _rebindRelay(normalized);
        _probe = _ServerProbe.online;
        emitIfOpen(_currentState());
      case RelayProbeStatus.offline:
        _probe = _ServerProbe.offline;
        emitIfOpen(_currentState());
      case RelayProbeStatus.versionMismatch:
        _probe = _ServerProbe.mismatch;
        _serverVersion = result.serverProtocolVersion;
        emitIfOpen(_currentState());
    }
  }

  // Rebinds the live relay client so the new server is used without
  // restarting the app. The settings page may outlive the relay client in
  // edge cases; a fresh start picks the saved URL up anyway.
  Future<void> _rebindRelay(String url) async {
    try {
      final LocationService locationService = GetIt.I<LocationService>();
      final RelayClient? relay = locationService.relayClient;
      if (relay != null && relay.baseUrl != url) {
        logger.i("Rebinding relay to $url");
        await relay.rebindRelay(url);
      }
    } catch (e) {
      logger.d("Relay rebind skipped: $e");
    }
  }

  /// Re-reads the OS background-fetch task status and last sync time.
  Future<void> refreshBackgroundStatus() async {
    _checkingBackground = true;
    emitIfOpen(_currentState());
    int status = -1;
    try {
      status = await BackgroundFetch.status;
    } catch (e) {
      logger.e("BackgroundFetch.status failed: $e");
    }
    _backgroundFetchStatus = status;
    _lastSync = prefs.getString('last-background-sync');
    _checkingBackground = false;
    emitIfOpen(_currentState());
  }

  /// Re-reads whether Android battery optimization is disabled for the app.
  Future<void> refreshBattery() async {
    _batteryExempt = await BatteryOptimizationService.isExempt();
    emitIfOpen(_currentState());
  }

  /// Opens the Android prompt to whitelist the app against battery
  /// optimization, then re-reads the result.
  Future<void> requestBatteryExemption() async {
    await BatteryOptimizationService.requestExemption();
    await refreshBattery();
  }

  /// Manual "send location now" used by the settings background section.
  Future<void> sendLocationNow() async {
    final LocationService locationService = GetIt.I<LocationService>();
    await locationService.sendLocationUpdateOneShot();
    await refreshBackgroundStatus();
  }

  // Builds the full state from the current probe stage + status fields.
  SettingsState _currentState() {
    return switch (_probe) {
      _ServerProbe.initial => SettingsInitial(
          batteryExempt: _batteryExempt,
          backgroundFetchStatus: _backgroundFetchStatus,
          lastBackgroundSync: _lastSync,
          checkingBackground: _checkingBackground,
        ),
      _ServerProbe.checking => SettingsServerChecking(
          batteryExempt: _batteryExempt,
          backgroundFetchStatus: _backgroundFetchStatus,
          lastBackgroundSync: _lastSync,
          checkingBackground: _checkingBackground,
        ),
      _ServerProbe.online => SettingsServerOnline(
          batteryExempt: _batteryExempt,
          backgroundFetchStatus: _backgroundFetchStatus,
          lastBackgroundSync: _lastSync,
          checkingBackground: _checkingBackground,
        ),
      _ServerProbe.offline => SettingsServerOffline(
          batteryExempt: _batteryExempt,
          backgroundFetchStatus: _backgroundFetchStatus,
          lastBackgroundSync: _lastSync,
          checkingBackground: _checkingBackground,
        ),
      _ServerProbe.mismatch => SettingsServerVersionMismatch(
          serverVersion: _serverVersion,
          batteryExempt: _batteryExempt,
          backgroundFetchStatus: _backgroundFetchStatus,
          lastBackgroundSync: _lastSync,
          checkingBackground: _checkingBackground,
        ),
    };
  }

  void emitIfOpen(SettingsState state) {
    if (!isClosed) emit(state);
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _probeSeq++; // invalidate in-flight probe emits
    controller.removeListener(_onUrlChanged);
    _lifecycleListener.dispose();
    return super.close();
  }
}