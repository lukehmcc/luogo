import 'dart:io';

import 'package:flutter/material.dart';

/// Shows whether Android battery optimization is disabled for the app and
/// offers a one-tap path to whitelist ("Unrestricted") it.
///
/// Pure presentation: status and the request action come from the settings
/// cubit. Hidden entirely once exempt unless [alwaysShow] is set (used in
/// Settings so the status always stays visible). Android only.
class BatteryOptimizationTile extends StatelessWidget {
  const BatteryOptimizationTile({
    super.key,
    required this.exempt,
    required this.onRequest,
    this.alwaysShow = false,
  });

  /// Whether the app is currently exempt from battery optimization.
  final bool exempt;

  /// Invoked when the user taps Allow.
  final VoidCallback onRequest;

  final bool alwaysShow;

  @override
  Widget build(BuildContext context) {
    // Battery optimization is an Android concept; never show this on iOS or
    // other platforms.
    if (!Platform.isAndroid) return const SizedBox.shrink();
    if (exempt && !alwaysShow) return const SizedBox.shrink();

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
          onPressed: exempt ? null : onRequest,
          child: const Text('Allow'),
        ),
      ),
    );
  }
}