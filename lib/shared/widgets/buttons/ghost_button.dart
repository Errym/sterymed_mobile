import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brandPrimary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.bodyStrong.copyWith(
              color: AppColors.brandPrimary,
              fontSize: 13,
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 2),
            Icon(icon, size: 14, color: AppColors.brandPrimary),
          ],
        ],
      ),
    );
  }
}
