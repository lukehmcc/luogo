import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/settings/settings_cubit.dart';
import 'package:luogo/cubit/home/settings/settings_state.dart';
import 'package:luogo/main.dart';
import 'package:luogo/view/widgets/battery_optimization_tile.dart';
import 'package:luogo/view/widgets/file_viewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Class that defines settings page
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: ListView(
              children: [
                const ListTile(
                  title: Text(
                    'Settings',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: TextField(
                      controller:
                          context.read<SettingsCubit>().controller,
                      decoration: InputDecoration(
                        labelText: 'Relay Server URL',
                        hintText: 'https://relay.luogo.app',
                        border: const OutlineInputBorder(),
                        suffixIcon: _statusIcon(state),
                      ),
                    )),
                _BackgroundStatusSection(state: state),
                BatteryOptimizationTile(
                  exempt: state.batteryExempt,
                  alwaysShow: true,
                  onRequest: () =>
                      context.read<SettingsCubit>().requestBatteryExemption(),
                ),
                Padding(
                  padding: EdgeInsetsGeometry.symmetric(horizontal: 50),
                  child: ElevatedButton(
                      onPressed: () async {
                        final Directory dir =
                            await getApplicationSupportDirectory();
                        final String logPath =
                            p.join(dir.path, 'log', 'latest.log');
                        logger.d("reading log from: $logPath");
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: const Text('Log Viewer')),
                                body: SafeArea(
                                  child: TextFileViewer(filePath: logPath),
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      child: Text("Logs")),
                ),
                Center(
                  child: Text(BlocProvider.of<SettingsCubit>(context).version),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Suffix icon for the relay URL field, driven by the live reachability probe.
Widget? _statusIcon(SettingsState state) {
  return switch (state) {
    SettingsServerChecking() => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    SettingsServerOnline() =>
      const Icon(Icons.check_circle, color: Colors.green),
    SettingsServerOffline() => const Icon(Icons.cancel, color: Colors.red),
    SettingsServerVersionMismatch() =>
      const Icon(Icons.warning_amber_rounded, color: Colors.orange),
    _ => null,
  };
}

/// Shows whether background location sync is allowed and when it last ran,
/// plus a manual "send now" trigger for testing. Fully driven by
/// [SettingsState].
class _BackgroundStatusSection extends StatelessWidget {
  const _BackgroundStatusSection({required this.state});

  final SettingsState state;

  String _statusLabel(int status) {
    switch (status) {
      case 2:
        return "Authorized";
      case 1:
        return "Denied";
      case 0:
        return "Restricted";
      default:
        return "Unknown";
    }
  }

  @override
  Widget build(BuildContext context) {
    final int fetchStatus = state.backgroundFetchStatus;
    final String statusText =
        fetchStatus == -1 ? "Unknown" : _statusLabel(fetchStatus);
    final String? lastSync = state.lastBackgroundSync;
    final String lastSyncText = (lastSync == null || lastSync.isEmpty)
        ? "Never"
        : lastSync.replaceFirst('T', ' ').replaceFirst(RegExp(r'\..*'), '');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Background sync',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: state.checkingBackground
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.schedule),
              title: const Text('OS task status'),
              subtitle: Text(statusText),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.history),
              title: const Text('Last background sync'),
              subtitle: Text(lastSyncText),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.location_on),
              label: const Text("Send location now"),
              onPressed: () async {
                final SettingsCubit cubit = context.read<SettingsCubit>();
                try {
                  await cubit.sendLocationNow();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Location sent")));
                } catch (e) {
                  logger.e("One-shot location send failed: $e");
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to send location")));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
