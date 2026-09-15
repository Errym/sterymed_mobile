import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/models/cycle_item_data.dart';

class CycleItemRow extends StatelessWidget {
  final CycleItemData item;
  final VoidCallback? onDelete;

  const CycleItemRow({super.key, required this.item, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description, style: AppTypography.bodyStrong),
                if (item.batchNumber != null) ...[
                  const SizedBox(height: 2),
                  Text('Lot ${item.batchNumber}', style: AppTypography.caption),
                ],
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.danger, size: 20),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
