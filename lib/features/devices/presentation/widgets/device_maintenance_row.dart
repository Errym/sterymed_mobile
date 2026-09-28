import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/models/maintenance_record_data.dart';

class DeviceMaintenanceRow extends StatelessWidget {
  final MaintenanceRecordData record;
  const DeviceMaintenanceRow({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: record.isOverdue
              ? AppColors.danger.withValues(alpha: 0.4)
              : AppColors.borderLight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.brandPrimaryLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.build_outlined,
                size: 18, color: AppColors.brandPrimary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(record.kindLabel,
                          style: AppTypography.bodyStrong),
                    ),
                    Text(_formatDate(record.performedAt),
                        style: AppTypography.caption),
                  ],
                ),
                if (record.technician != null &&
                    record.technician!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(record.technician!, style: AppTypography.caption),
                ],
                if (record.description != null &&
                    record.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(record.description!, style: AppTypography.caption),
                ],
                if (record.nextDueAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Prochaine échéance : ${_formatDate(record.nextDueAt!)}',
                    style: AppTypography.caption.copyWith(
                      color: record.isOverdue
                          ? AppColors.danger
                          : AppColors.textSecondary,
                      fontWeight:
                          record.isOverdue ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}
