import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/models/cycle_data.dart';

/// Renders the cycle's full path, not just the steps already reached, so a
/// technician always sees the whole journey with the current position
/// highlighted and what's still ahead dimmed — the same convention as a
/// shipping tracker or a hospital cycle-status board.
class CycleTimeline extends StatelessWidget {
  final CycleData cycle;
  const CycleTimeline({super.key, required this.cycle});

  static const _order = [
    'created',
    'in_progress',
    'completed',
    'awaiting_release',
    'released', // 'rejected' takes this slot instead when it applies
  ];

  @override
  Widget build(BuildContext context) {
    final isRejected = cycle.status == 'rejected';
    final currentIndex = isRejected ? 4 : _order.indexOf(cycle.status);

    final steps = <_Step>[
      _Step('Créé', cycle.createdAt, Icons.add_circle_outline),
      _Step('En cours', cycle.startedAt, Icons.play_circle_outline),
      _Step('Terminé', cycle.completedAt, Icons.check_circle_outline),
      _Step('En attente de libération', null, Icons.hourglass_top_outlined),
      _Step(
        isRejected ? 'Rejeté' : 'Libéré',
        cycle.releasedAt,
        isRejected ? Icons.cancel_outlined : Icons.verified_outlined,
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
            state: i < currentIndex
                ? _StepState.done
                : i == currentIndex
                    ? (isRejected ? _StepState.rejected : _StepState.current)
                    : _StepState.future,
            isFirst: i == 0,
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

enum _StepState { done, current, rejected, future }

class _Step {
  final String label;
  final DateTime? at;
  final IconData icon;
  _Step(this.label, this.at, this.icon);
}

class _TimelineEntry extends StatelessWidget {
  final String title;
  final DateTime? timestamp;
  final IconData icon;
  final _StepState state;
  final bool isFirst;
  final bool isLast;

  const _TimelineEntry({
    required this.title,
    required this.timestamp,
    required this.icon,
    required this.state,
    required this.isFirst,
    required this.isLast,
  });

  Color get _color => switch (state) {
        _StepState.done => AppColors.success,
        _StepState.current => AppColors.brandPrimary,
        _StepState.rejected => AppColors.danger,
        _StepState.future => AppColors.textTertiary,
      };

  @override
  Widget build(BuildContext context) {
    final dim = state == _StepState.future;
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
                  color: dim
                      ? AppColors.backgroundMuted
                      : _color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: dim ? Border.all(color: AppColors.borderMedium) : null,
                ),
                child: Icon(icon, size: 16, color: _color),
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
                  Text(
                    title,
                    style: dim
                        ? AppTypography.bodyStrong
                            .copyWith(color: AppColors.textTertiary)
                        : AppTypography.bodyStrong,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timestamp != null
                        ? _formatDateTime(timestamp!)
                        : (dim ? 'À venir' : '—'),
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
