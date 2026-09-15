import 'package:flutter/material.dart';

import '../../../../shared/widgets/badges/status_badge.dart';

class CycleStatusBadge extends StatelessWidget {
  final String status;
  const CycleStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'created':
        return const StatusBadge(
          label: 'Créé',
          tone: StatusTone.neutral,
          icon: Icons.fiber_new,
        );
      case 'in_progress':
        return const StatusBadge(
          label: 'En cours',
          tone: StatusTone.info,
          icon: Icons.play_circle_outline,
        );
      case 'completed':
        return const StatusBadge(
          label: 'Terminé',
          tone: StatusTone.warning,
          icon: Icons.check_circle_outline,
        );
      case 'awaiting_release':
        return const StatusBadge(
          label: 'À libérer',
          tone: StatusTone.warning,
          icon: Icons.hourglass_bottom,
        );
      case 'released':
        return const StatusBadge(
          label: 'Libéré',
          tone: StatusTone.success,
          icon: Icons.verified_outlined,
        );
      case 'rejected':
        return const StatusBadge(
          label: 'Rejeté',
          tone: StatusTone.danger,
          icon: Icons.cancel_outlined,
        );
      default:
        return StatusBadge(label: status, tone: StatusTone.neutral);
    }
  }
}
