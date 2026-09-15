import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class DangerButton extends StatelessWidget {
  const DangerButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isFullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.danger,
          foregroundColor: AppColors.textOnBrand,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(label, style: AppTypography.buttonLabel),
          ],
        ),
      ),
    );
  }
}
