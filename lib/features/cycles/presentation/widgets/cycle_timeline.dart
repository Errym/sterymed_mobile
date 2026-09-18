import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
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
          _TimelineEntry(
            title: steps[i].label,
            timestamp: steps[i].at,
            icon: steps[i].icon,
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

class _TimelineEntry extends StatelessWidget {
  final String title;
  final DateTime timestamp;
  final IconData icon;
  final Color color;
  final bool isFirst;
  final bool isLast;

  const _TimelineEntry({
    required this.title,
    required this.timestamp,
    required this.icon,
    required this.color,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.borderLight,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyStrong),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateTime(timestamp),
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} · '
        '${two(d.hour)}:${two(d.minute)}';
  }
}
