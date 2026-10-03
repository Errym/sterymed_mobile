import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/models/cycle_item_data.dart';

/// Compact instrument row shown inline on the cycle detail screen — offers
/// both edit and delete via a popup menu. Distinct from [CycleItemRow]
/// (delete-only, used on the dedicated cycle items list screen).
class CycleDetailItemRow extends StatelessWidget {
  final CycleItemData item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CycleDetailItemRow({
    super.key,
    required this.item,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
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
          if (onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  size: 20, color: AppColors.textSecondary),
              onSelected: (v) {
                if (v == 'edit') onEdit?.call();
                if (v == 'delete') onDelete?.call();
              },
              itemBuilder: (_) => [
                if (onEdit != null)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Modifier'),
                    ]),
                  ),
                if (onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 18, color: AppColors.danger),
                      SizedBox(width: 8),
                      Text('Supprimer',
                          style: TextStyle(color: AppColors.danger)),
                    ]),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
