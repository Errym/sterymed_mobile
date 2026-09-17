import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../data/models/stock_level_data.dart';

class StockLevelTile extends StatelessWidget {
  final StockLevelData level;
  final VoidCallback? onTap;

  const StockLevelTile({super.key, required this.level, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: level.isExpired
                  ? AppColors.danger.withValues(alpha: 0.4)
                  : level.isLow
                      ? AppColors.warning.withValues(alpha: 0.4)
                      : AppColors.borderLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(level.productName,
                        style: AppTypography.bodyStrong),
                  ),
                  Text(
                    '${level.qty} ${level.unit}',
                    style: AppTypography.bodyStrong.copyWith(
                      color: level.isLow
                          ? AppColors.warning
                          : AppColors.brandPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${level.reference} · ${level.locationName}',
                style: AppTypography.caption,
              ),
              if (level.batchNumber != null || level.expiryDate != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (level.batchNumber != null)
                      TypeBadge(
                        label: 'Lot ${level.batchNumber}',
                        tone: BadgeTone.gray,
                      ),
                    if (level.expiryDate != null)
                      TypeBadge(
                        label: level.isExpired
                            ? 'Périmé'
                            : 'DLC ${DateFormat('dd/MM/yy').format(level.expiryDate!)}',
                        tone: level.isExpired
                            ? BadgeTone.red
                            : level.isNearExpiry
                                ? BadgeTone.orange
                                : BadgeTone.green,
                      ),
                    if (level.isLow)
                      const TypeBadge(
                          label: 'Stock faible', tone: BadgeTone.yellow),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
