import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/badges/aging_badge.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../data/models/prosthetic_case_data.dart';

BadgeTone prostheticStatusTone(ProstheticCaseStatus status) => switch (status) {
      ProstheticCaseStatus.impressionCompleted => BadgeTone.blue,
      ProstheticCaseStatus.sentToLaboratory => BadgeTone.purple,
      ProstheticCaseStatus.receivedAtPractice => BadgeTone.yellow,
      ProstheticCaseStatus.placementScheduled => BadgeTone.orange,
      ProstheticCaseStatus.placed => BadgeTone.green,
      ProstheticCaseStatus.cancelled => BadgeTone.red,
      ProstheticCaseStatus.unknown => BadgeTone.gray,
    };

class ProstheticCaseTile extends StatelessWidget {
  final ProstheticCaseData item;
  final VoidCallback? onTap;

  const ProstheticCaseTile({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final accent = item.status == ProstheticCaseStatus.cancelled
        ? AppColors.danger
        : item.daysWaitingForPlacement != null
            ? (item.daysWaitingForPlacement! >= 15
                ? AppColors.agingUrgent
                : item.daysWaitingForPlacement! >= 8
                    ? AppColors.agingMedium
                    : AppColors.agingFresh)
            : AppColors.brandPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.hairline),
            boxShadow: AppShadows.card,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.patientReference,
                                  style: AppTypography.cardTitle,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              TypeBadge(
                                label: item.status.label,
                                tone: prostheticStatusTone(item.status),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceWell,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.control),
                            ),
                            child: Text(
                              '${item.workType.label} · ${item.practitionerName}',
                              style: AppTypography.bodyStrong,
                            ),
                          ),
                          if (item.laboratoryName != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                                const Icon(
                                  Icons.science_outlined,
                                  size: 14,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item.laboratoryName!,
                                    style: AppTypography.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              const Icon(
                                Icons.event_outlined,
                                size: 14,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateFmt.format(item.impressionDate),
                                style: AppTypography.caption,
                              ),
                              if (item.daysWaitingForPlacement != null) ...[
                                const Spacer(),
                                AgingBadge(
                                  daysElapsed: item.daysWaitingForPlacement!,
                                  prominent: true,
                                ),
                              ],
                              if (item.hasPaymentDue) ...[
                                const SizedBox(width: AppSpacing.sm),
                                const Icon(
                                  Icons.euro,
                                  size: 14,
                                  color: AppColors.danger,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
