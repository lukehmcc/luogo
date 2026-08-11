import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/server_select/server_select_state.dart';
import 'package:luogo/services/relay_health.dart';

/// A Cubit class for the relay server picker shown during profile creation.
///
/// Probes the candidate URL live as the user types — the same debounce,
/// stale-probe guard and shared health check as the Settings page — so the
/// dialog can only confirm a relay that actually answered with a compatible
/// protocol version.
class ServerSelectCubit extends Cubit<ServerSelectState> {
  ServerSelectCubit({required String initialUrl}) : super(ServerSelectInitial()) {
    controller.text = initialUrl;
    controller.addListener(_onUrlChanged);
    // Check the prefilled server as soon as the dialog opens.
    _scheduleProbe();
  }

  TextEditingController controller = TextEditingController();

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
      emitIfOpen(ServerSelectOffline());
      return;
    }
    emitIfOpen(ServerSelectChecking());
    _debounce = Timer(_probeDebounce, () => _probeUrl(url));
  }

  Future<void> _probeUrl(String url) async {
    final int seq = ++_probeSeq;
    final RelayProbeResult result = await probeRelayHealth(url);
    if (seq != _probeSeq || isClosed) return; // superseded
    switch (result.status) {
      case RelayProbeStatus.online:
        emitIfOpen(ServerSelectOnline());
      case RelayProbeStatus.offline:
        emitIfOpen(ServerSelectOffline());
      case RelayProbeStatus.versionMismatch:
        emitIfOpen(
            ServerSelectVersionMismatch(serverVersion: result.serverProtocolVersion));
    }
  }

  void emitIfOpen(ServerSelectState state) {
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