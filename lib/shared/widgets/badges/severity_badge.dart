import 'package:flutter/material.dart';

import 'status_badge.dart';

class SeverityBadge extends StatelessWidget {
  final String severity; // 'critical', 'warning', 'info'

  const SeverityBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    switch (severity) {
      case 'critical':
        return const StatusBadge(label: 'Critique', tone: StatusTone.danger);
      case 'warning':
        return const StatusBadge(
          label: 'Avertissement',
          tone: StatusTone.warning,
        );
      default:
        return const StatusBadge(label: 'Info', tone: StatusTone.info);
    }
  }
}
