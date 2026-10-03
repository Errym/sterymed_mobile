import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../data/models/stock_level_data.dart';
import 'stock_level_style.dart';

/// One stock row, laid out like a clinical record card: reference and lot as a
/// small eyebrow, the product name, a status pill, a gauge against the minimum
/// threshold, then the quantity in large tabular figures with its place.
class StockLevelTile extends StatelessWidget {
  final StockLevelData level;
  final VoidCallback? onTap;

  const StockLevelTile({super.key, required this.level, this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = stockStatusOf(level);
    final eyebrow = [
      level.reference,
      if (level.batchNumber != null) 'LOT ${level.batchNumber}',
    ].where((s) => s.isNotEmpty).join('  ·  ');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWell,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(
                  level.expiryDate != null
                      ? Icons.medication_outlined
                      : Icons.inventory_2_outlined,
                  size: 21,
                  color: AppColors.navyHeader,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow.isNotEmpty)
                      Text(
                        eyebrow,
                        style: AppTypography.caption.copyWith(
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    Text(
                      level.productName,
                      style: AppTypography.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(label: status.label, tone: status.tone),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: stockGaugeOf(level),
              minHeight: 6,
              backgroundColor: AppColors.backgroundMuted,
              valueColor: AlwaysStoppedAnimation<Color>(status.color),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${level.qty}',
                style: AppTypography.metric.copyWith(
                  fontSize: 26,
                  color: level.isLow || level.isExpired
                      ? status.color
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    level.minThreshold > 0
                        ? '${level.unit}  /  min. ${level.minThreshold}'
                        : level.unit,
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        level.locationName,
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (level.expiryDate != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              level.isExpired
                  ? 'Périmé depuis le '
                      '${DateFormat('dd/MM/yy').format(level.expiryDate!)}'
                  : 'DLC ${DateFormat('dd/MM/yy').format(level.expiryDate!)}',
              style: AppTypography.caption.copyWith(
                color: level.isExpired
                    ? AppColors.danger
                    : level.isNearExpiry
                        ? AppColors.warning
                        : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
