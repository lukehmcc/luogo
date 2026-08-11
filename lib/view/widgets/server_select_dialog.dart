import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/server_select/server_select_cubit.dart';
import 'package:luogo/cubit/server_select/server_select_state.dart';
import 'package:luogo/services/relay_client.dart';

/// Lets the user pick which relay their profile will use. Prefilled with the
/// current server (defaulting to the packaged relay URL) and validated live
/// with the same probe as the Settings page: the confirm button stays
/// disabled until a compatible relay answers.
class ServerSelectDialog extends StatelessWidget {
  final String initialUrl;
  const ServerSelectDialog({super.key, required this.initialUrl});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ServerSelectCubit>(
      create: (BuildContext context) =>
          ServerSelectCubit(initialUrl: initialUrl),
      child: BlocBuilder<ServerSelectCubit, ServerSelectState>(
        builder: (BuildContext context, ServerSelectState state) {
          final ServerSelectCubit cubit = context.read<ServerSelectCubit>();
          return AlertDialog(
            title: const Text('Select server'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: cubit.controller,
                  decoration: InputDecoration(
                    labelText: 'Relay Server URL',
                    hintText: kDefaultRelayUrl,
                    border: const OutlineInputBorder(),
                    suffixIcon: _statusIcon(state),
                  ),
                ),
                if (_statusMessage(state) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _statusMessage(state)!,
                      style: TextStyle(
                        color: state is ServerSelectVersionMismatch
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
                // Stale probes never emit, so the current state is always the
                // latest result.
                onPressed: state is ServerSelectOnline
                    ? () => Navigator.of(context)
                        .pop(normalizeRelayUrl(cubit.controller.text.trim()))
                    : null,
                child: const Text('Use this server'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget? _statusIcon(ServerSelectState state) {
    return switch (state) {
      ServerSelectChecking() => const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ServerSelectOnline() =>
        const Icon(Icons.check_circle, color: Colors.green),
      ServerSelectOffline() => const Icon(Icons.cancel, color: Colors.red),
      ServerSelectVersionMismatch() =>
        const Icon(Icons.warning_amber_rounded, color: Colors.orange),
      ServerSelectInitial() => null,
    };
  }
    String? _statusMessage(ServerSelectState state) {
    switch (state) {
      case ServerSelectOnline():
        return null;
      case ServerSelectOffline():
        return 'No relay answered at this address.';
      case ServerSelectVersionMismatch(:final serverVersion):
        return 'This relay speaks protocol version $serverVersion, but this app uses $kProtocolVersion. Update your relay.';
      case ServerSelectChecking() || ServerSelectInitial():
        return null;
    }
  }
}