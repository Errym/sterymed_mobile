import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import 'app_card.dart';

class InfoCard extends StatelessWidget {
  final String label;
  final String? value;
  final IconData? icon;
  final Widget? trailing;

  const InfoCard({
    super.key,
    required this.label,
    this.value,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.brandPrimary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.label),
                if (value != null) ...[
                  const SizedBox(height: 2),
                  Text(value!, style: AppTypography.bodyStrong),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
