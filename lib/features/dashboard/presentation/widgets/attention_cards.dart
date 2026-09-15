import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/models/dashboard_data.dart';

class AttentionCards extends StatelessWidget {
  final List<DashboardAttentionItem> items;
  final void Function(String route) onTap;

  const AttentionCards({super.key, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Tout est à jour',
                style: AppTypography.bodyStrong.copyWith(
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nécessite votre attention',
          style: AppTypography.sectionTitle,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _AttentionTile(
              item: item,
              onTap: () => onTap(item.route),
            ),
          ),
      ],
    );
  }
}

class _AttentionTile extends StatelessWidget {
  final DashboardAttentionItem item;
  final VoidCallback onTap;

  const _AttentionTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (item.severity) {
      'critical' => (
          AppColors.dangerLight,
          AppColors.danger,
          Icons.error_outline
        ),
      'warning' => (
          AppColors.warningLight,
          AppColors.warning,
          Icons.warning_amber_outlined
        ),
      _ => (AppColors.infoLight, AppColors.info, Icons.info_outline),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.label,
                  style: AppTypography.bodyStrong.copyWith(color: fg),
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textTertiary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
