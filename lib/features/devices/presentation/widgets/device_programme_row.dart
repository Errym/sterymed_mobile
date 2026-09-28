import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../cycles/data/models/device_program_data.dart';

class DeviceProgrammeRow extends StatelessWidget {
  final DeviceProgramData program;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const DeviceProgrammeRow({
    super.key,
    required this.program,
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
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: program.isActive
                  ? AppColors.brandPrimaryLight
                  : AppColors.backgroundMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.thermostat_outlined,
              size: 18,
              color: program.isActive
                  ? AppColors.brandPrimary
                  : AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(program.name, style: AppTypography.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  '${program.temperatureCelsius} °C · '
                  '${program.plateauMinutes} min'
                  '${program.isActive ? '' : ' · Inactif'}',
                  style: AppTypography.caption,
                ),
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
