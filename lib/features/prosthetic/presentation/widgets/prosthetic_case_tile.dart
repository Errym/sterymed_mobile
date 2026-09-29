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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.patientReference,
                      style: AppTypography.bodyStrong),
                ),
                TypeBadge(
                  label: item.status.label,
                  tone: prostheticStatusTone(item.status),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${item.workType.label} · ${item.practitionerName}',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            if (item.laboratoryName != null) ...[
              const SizedBox(height: 2),
              Text(
                item.laboratoryName!,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(Icons.event_outlined,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(dateFmt.format(item.impressionDate),
                    style: AppTypography.caption),
                if (item.daysWaitingForPlacement != null) ...[
                  const Spacer(),
                  AgingBadge(
                    daysElapsed: item.daysWaitingForPlacement!,
                    prominent: true,
                  ),
                ],
                if (item.hasPaymentDue) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.euro, size: 14, color: AppColors.danger),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
