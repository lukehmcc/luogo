import 'dart:async';

import 'package:flutter/material.dart';
import 'package:luogo/services/relay_client.dart';
import 'package:luogo/services/relay_health.dart';

/// Lets the user pick which relay their profile will use. Prefilled with the
/// current server (defaulting to the packaged relay URL) and validated live
/// with the same probe as the Settings page: the confirm button stays
/// disabled until a compatible relay answers.
class ServerSelectDialog extends StatefulWidget {
  final String initialUrl;
  const ServerSelectDialog({super.key, required this.initialUrl});

  @override
  State<ServerSelectDialog> createState() => _ServerSelectDialogState();
}

class _ServerSelectDialogState extends State<ServerSelectDialog> {
  late final TextEditingController _controller;
  Timer? _debounce;
  int _probeSeq = 0;
  bool _checking = true;
  RelayProbeStatus _status = RelayProbeStatus.offline;
  int _serverVersion = 0;
  int _lastOnlineSeq = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
    _controller.addListener(_onChanged);
    _scheduleProbe();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _probeSeq++; // invalidate in-flight probe emits
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() => _scheduleProbe();

  // Same debounce/guard rhythm as the Settings page probe.
  void _scheduleProbe() {
    _debounce?.cancel();
    final String url = _controller.text.trim();
    if (url.isEmpty) {
      _probeSeq++;
      setState(() {
        _checking = false;
        _status = RelayProbeStatus.offline;
      });
      return;
    }
    setState(() => _checking = true);
    _debounce = Timer(const Duration(milliseconds: 500), () => _probe(url));
  }

  Future<void> _probe(String url) async {
    final int seq = ++_probeSeq;
    final RelayProbeResult result = await probeRelayHealth(url);
    if (!mounted || seq != _probeSeq) return; // superseded
    setState(() {
      _checking = false;
      _status = result.status;
      _serverVersion = result.serverProtocolVersion;
      if (result.status == RelayProbeStatus.online) _lastOnlineSeq = seq;
    });
  }

  // Only the most recent probe being a success keeps the confirm live.
  bool get _canConfirm => !_checking && _lastOnlineSeq == _probeSeq;

  Widget? _statusIcon() {
    if (_checking) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return switch (_status) {
      RelayProbeStatus.online =>
        const Icon(Icons.check_circle, color: Colors.green),
      RelayProbeStatus.offline => const Icon(Icons.cancel, color: Colors.red),
      RelayProbeStatus.versionMismatch =>
        const Icon(Icons.warning_amber_rounded, color: Colors.orange),
    };
  }

  String? get _statusMessage {
    switch (_status) {
      case RelayProbeStatus.online:
        return null;
      case RelayProbeStatus.offline:
        return 'No relay answered at this address.';
      case RelayProbeStatus.versionMismatch:
        return 'This relay speaks protocol version $_serverVersion, but this app uses $kProtocolVersion. Update your relay.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select server'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Relay Server URL',
              hintText: kDefaultRelayUrl,
              border: const OutlineInputBorder(),
              suffixIcon: _statusIcon(),
            ),
          ),
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _statusMessage!,
                style: TextStyle(
                  color: _status == RelayProbeStatus.versionMismatch
                      ? Colors.orange.shade800
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canConfirm
              ? () => Navigator.of(context)
                  .pop(normalizeRelayUrl(_controller.text.trim()))
              : null,
          child: const Text('Use this server'),
        ),
      ],
    );
  }
}