import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:luogo/cubit/home/settings/settings_state.dart';
import 'package:luogo/main.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/services/relay_client.dart';
import 'package:luogo/services/relay_health.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Cubit class for managing the settings state.
///
/// Probes the relay URL live as the user types: a reachable server gets
/// saved and the running relay client rebinds to it immediately.
class SettingsCubit extends Cubit<SettingsState> {
  SharedPreferencesWithCache prefs;
  SettingsCubit({
    required this.prefs,
  }) : super(SettingsInitial()) {
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
  }

  TextEditingController controller = TextEditingController();
  String version = "";

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
      emitIfOpen(SettingsInitial());
      return;
    }
    emitIfOpen(SettingsServerChecking());
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
      emitIfOpen(SettingsServerOffline());
      return;
    }
    final String normalized = normalizeRelayUrl(url);
    final RelayProbeResult result = await probeRelayHealth(normalized);
    if (seq != _probeSeq || isClosed) return; // superseded
    switch (result.status) {
      case RelayProbeStatus.online:
        await prefs.setString('server-url', normalized);
        await _rebindRelay(normalized);
        emitIfOpen(SettingsServerOnline());
      case RelayProbeStatus.offline:
        emitIfOpen(SettingsServerOffline());
      case RelayProbeStatus.versionMismatch:
        emitIfOpen(SettingsServerVersionMismatch(
            serverVersion: result.serverProtocolVersion));
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

  void emitIfOpen(SettingsState state) {
    if (!isClosed) emit(state);
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _probeSeq++; // invalidate in-flight probe emits
    controller.removeListener(_onUrlChanged);
    return super.close();
  }
}