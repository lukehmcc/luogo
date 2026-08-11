import 'dart:io';

import 'package:flutter/material.dart';
import 'package:luogo/services/battery_optimization.dart';

/// Shows whether Android battery optimization is disabled for the app and
/// offers a one-tap path to whitelist ("Unrestricted") it.
///
/// Hidden entirely once the app is exempt unless [alwaysShow] is set (used in
/// Settings so the status always stays visible).
class BatteryOptimizationTile extends StatefulWidget {
  const BatteryOptimizationTile({super.key, this.alwaysShow = false});

  final bool alwaysShow;

  @override
  State<BatteryOptimizationTile> createState() =>
      _BatteryOptimizationTileState();
}

class _BatteryOptimizationTileState extends State<BatteryOptimizationTile>
    with WidgetsBindingObserver {
  bool? _exempt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when the user returns from the Android settings screen.
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final bool exempt = await BatteryOptimizationService.isExempt();
    if (!mounted) return;
    setState(() => _exempt = exempt);
  }

  @override
  Widget build(BuildContext context) {
    // Battery optimization is an Android concept; never show this on iOS or
    // other platforms.
    if (!Platform.isAndroid) return const SizedBox.shrink();

    final bool? exempt = _exempt;
    if (exempt == null) return const SizedBox.shrink();
    if (exempt && !widget.alwaysShow) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ListTile(
        leading: Icon(
          exempt ? Icons.battery_std : Icons.battery_alert,
          color: exempt ? Colors.green : Colors.orange,
        ),
        title: const Text('Reduced battery optimization'),
        subtitle: Text(
          exempt
              ? 'Luogo is exempt from battery optimization.'
              : 'Optimized mode can delay background location sharing. '
                  'Allow "Unrestricted" battery usage for reliable updates.',
        ),
        trailing: FilledButton(
          onPressed: exempt
              ? null
              : () async {
                  await BatteryOptimizationService.requestExemption();
                  await _refresh();
                },
          child: const Text('Allow'),
        ),
      ),
    );
  }
}
