import 'package:flutter/material.dart';

import '../badges/status_badge.dart';

class EnvironmentBadge extends StatelessWidget {
  final String environment;

  const EnvironmentBadge({super.key, required this.environment});

  @override
  Widget build(BuildContext context) {
    switch (environment.toLowerCase()) {
      case 'production':
        return const StatusBadge(label: 'Production', tone: StatusTone.success);
      case 'staging':
        return const StatusBadge(label: 'Staging', tone: StatusTone.warning);
      default:
        return const StatusBadge(label: 'Dev', tone: StatusTone.info);
    }
  }
}
