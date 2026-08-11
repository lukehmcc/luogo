import 'package:flutter/material.dart';

/// A shared permission prompt card: shows a spinner while [checking], then a
/// red X until [granted] and a green check once granted. The Allow button is
/// disabled while checking or once granted.
class PermissionTile extends StatelessWidget {
  const PermissionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.checking,
    required this.onRequest,
  });

  final String title;
  final String subtitle;
  final bool granted;
  final bool checking;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final Widget icon;
    if (checking) {
      icon = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    } else if (granted) {
      icon = const Icon(Icons.check_circle, color: Colors.green);
    } else {
      icon = const Icon(Icons.cancel, color: Colors.red);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ListTile(
        leading: icon,
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: FilledButton(
          onPressed: (granted || checking) ? null : onRequest,
          child: const Text('Allow'),
        ),
      ),
    );
  }
}