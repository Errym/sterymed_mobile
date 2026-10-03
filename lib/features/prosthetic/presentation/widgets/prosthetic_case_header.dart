import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/formatters/currency_formatter.dart';
import '../../../../shared/widgets/badges/aging_badge.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../data/models/prosthetic_case_data.dart';
import 'prosthetic_case_tile.dart';

/// The brief's one-line workflow, impression → placement.
const prostheticStages = ['Empreinte', 'Laboratoire', 'Reçu', 'Pose prévue', 'Posé'];

/// Where a case stands in that flow (0-4). A cancelled case has none.
int? prostheticStageOf(ProstheticCaseStatus s) => switch (s) {
      ProstheticCaseStatus.impressionCompleted => 0,
      ProstheticCaseStatus.sentToLaboratory => 1,
      ProstheticCaseStatus.receivedAtPractice => 2,
      ProstheticCaseStatus.placementScheduled => 3,
      ProstheticCaseStatus.placed => 4,
      _ => null,
    };

/// Brief §8: before "Placed", warn (never block) when money is still due.
/// Returns the sentence to show, or null when nothing is outstanding.
String? prostheticPaymentWarning(ProstheticCaseData c) {
  final beforePlacement = c.status == ProstheticCaseStatus.receivedAtPractice ||
      c.status == ProstheticCaseStatus.placementScheduled;
  if (!beforePlacement) return null;
  final balance = c.remainingBalance;
  if (balance != null && balance > 0) {
    return 'Reste à payer : ${AppCurrencyFormatter.eur(balance)}. À vérifier avant la pose.';
  }
  if (c.depositRequested && !c.depositReceived) {
    return 'Acompte demandé et non reçu. À vérifier avant la pose.';
  }
  return null;
}

class ProstheticCaseHeader extends StatelessWidget {
  final ProstheticCaseData data;
  const ProstheticCaseHeader({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = data;
    final stage = prostheticStageOf(c.status);
    final cancelled = c.status == ProstheticCaseStatus.cancelled;
    final warning = prostheticPaymentWarning(c);
    final waiting = c.daysWaitingForPlacement;
    final showAging = waiting != null &&
        c.status != ProstheticCaseStatus.placed &&
        !cancelled;
    final date = DateFormat('dd/MM/yyyy');

    return AppCard(
      key: const Key('prosthetic-header'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${c.workType.label} · ${c.practitionerName}'.toUpperCase(),
                      style: AppTypography.eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(c.patientReference, style: AppTypography.pageTitle),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TypeBadge(label: c.status.label, tone: prostheticStatusTone(c.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (cancelled)
            Container(
              key: const Key('prosthetic-cancelled'),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Text(
                'Ce travail est annulé. Il n\'apparaît plus dans les travaux actifs.',
                style: AppTypography.bodyStrong.copyWith(color: AppColors.danger),
              ),
            )
          else
            _Stepper(stage: stage ?? 0),
          if (showAging) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              key: const Key('prosthetic-aging'),
              children: [
                AgingBadge(daysElapsed: waiting, prominent: true),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'depuis le retour du laboratoire',
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ],
          if (warning != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              key: const Key('prosthetic-payment-warning'),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.euro, size: 16, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(warning, style: AppTypography.body)),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Fact('Laboratoire', c.laboratoryName ?? '—'),
              _Fact(
                'Pose prévue',
                c.plannedPlacementDate == null ? '—' : date.format(c.plannedPlacementDate!),
              ),
              _Fact(
                'Reste à payer',
                c.remainingBalance == null ? '—' : AppCurrencyFormatter.eur(c.remainingBalance!),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  const _Fact(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTypography.eyebrow, maxLines: 1),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.bodyStrong,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int stage;
  const _Stepper({required this.stage});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('prosthetic-stepper'),
      children: [
        Row(
          children: [
            for (var i = 0; i < prostheticStages.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i <= stage ? AppColors.brandPrimary : AppColors.hairline,
                  ),
                ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= stage ? AppColors.brandPrimary : AppColors.backgroundCard,
                  border: Border.all(
                    color: i <= stage ? AppColors.brandPrimary : AppColors.hairline,
                    width: 2,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < prostheticStages.length; i++)
              Expanded(
                child: Text(
                  prostheticStages[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == prostheticStages.length - 1
                          ? TextAlign.right
                          : TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    fontWeight: i == stage ? FontWeight.w700 : FontWeight.w400,
                    color: i == stage ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
