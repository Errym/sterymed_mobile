import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/timeline/timeline_entry.dart';
import '../../data/models/cycle_data.dart';

class CycleTimeline extends StatelessWidget {
  final CycleData cycle;
  const CycleTimeline({super.key, required this.cycle});

  @override
  Widget build(BuildContext context) {
    final steps = <_Step>[
      _Step('Créé', cycle.createdAt, Icons.add_circle_outline),
      if (cycle.startedAt != null)
        _Step('En cours', cycle.startedAt!, Icons.play_circle_outline),
      if (cycle.completedAt != null)
        _Step('Terminé', cycle.completedAt!, Icons.check_circle_outline),
      if (cycle.releasedAt != null)
        _Step(
          cycle.status == 'rejected' ? 'Rejeté' : 'Libéré',
          cycle.releasedAt!,
          cycle.status == 'rejected'
              ? Icons.cancel_outlined
              : Icons.verified_outlined,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          TimelineEntry(
            title: steps[i].label,
            timestamp: steps[i].at,
            color: i == steps.length - 1
                ? AppColors.brandPrimary
                : AppColors.success,
            isFirst: i == 0,
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _Step {
  final String label;
  final DateTime at;
  final IconData icon;
  _Step(this.label, this.at, this.icon);
}
