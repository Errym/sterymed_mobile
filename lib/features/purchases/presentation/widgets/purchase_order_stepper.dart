import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// Compact horizontal status stepper for a purchase order's lifecycle,
/// following the same "show the whole path, dim what's ahead" convention
/// as `CycleTimeline`. Purchase orders don't carry a timestamp per status
/// (only `created_at`/`ordered_at` — confirmed against `PurchaseOrderData`
/// and the real `PurchaseOrderStatus` enum), so unlike cycles this is dots
/// + labels only, no per-step time.
///
/// Not shown for `cancelled` — that's a terminal exit from any point in
/// the path, not a position on it, and the existing status badge already
/// communicates it on its own.
class PurchaseOrderStepper extends StatelessWidget {
  final String status;
  const PurchaseOrderStepper({super.key, required this.status});

  static const _order = [
    'draft',
    'ordered',
    'partially_received',
    'received',
    'closed',
  ];
  static const _labels = [
    'Brouillon',
    'Commandé',
    'Partiel',
    'Reçu',
    'Clôturé',
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _order.indexOf(status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _order.length; i++) ...[
          _StepDot(
            label: _labels[i],
            state: i < currentIndex
                ? _DotState.done
                : i == currentIndex
                    ? _DotState.current
                    : _DotState.future,
          ),
          if (i != _order.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Container(
                  height: 2,
                  color: i < currentIndex
                      ? AppColors.success
                      : AppColors.borderLight,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

enum _DotState { done, current, future }

class _StepDot extends StatelessWidget {
  final String label;
  final _DotState state;
  const _StepDot({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _DotState.done => AppColors.success,
      _DotState.current => AppColors.brandPrimary,
      _DotState.future => AppColors.textTertiary,
    };
    final dim = state == _DotState.future;

    return SizedBox(
      width: 62,
      child: Column(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: dim ? AppColors.backgroundMuted : color,
              shape: BoxShape.circle,
              border: dim ? Border.all(color: AppColors.borderMedium) : null,
            ),
            child: state == _DotState.done
                ? const Icon(Icons.check, size: 10, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: dim ? AppColors.textTertiary : AppColors.textPrimary,
              fontWeight: state == _DotState.current
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
