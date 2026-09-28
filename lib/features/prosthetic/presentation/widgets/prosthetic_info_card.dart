import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class ProstheticInfoCard extends StatelessWidget {
  final List<(String, String)> rows;
  const ProstheticInfoCard({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(rows[i].$1, style: AppTypography.label),
                  ),
                  Text(rows[i].$2, style: AppTypography.bodyStrong),
                ],
              ),
            ),
            if (i != rows.length - 1)
              const Divider(height: 1, color: AppColors.borderLight),
          ],
        ],
      ),
    );
  }
}
