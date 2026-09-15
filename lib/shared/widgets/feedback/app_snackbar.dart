import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

enum SnackKind { info, success, warning, error }

abstract final class AppSnackbar {
  static void show(
    BuildContext context,
    String message, {
    SnackKind kind = SnackKind.info,
  }) {
    Color bg;
    IconData icon;
    switch (kind) {
      case SnackKind.success:
        bg = AppColors.success;
        icon = Icons.check_circle_outline;
        break;
      case SnackKind.warning:
        bg = AppColors.warning;
        icon = Icons.warning_amber_outlined;
        break;
      case SnackKind.error:
        bg = AppColors.danger;
        icon = Icons.error_outline;
        break;
      case SnackKind.info:
        bg = AppColors.brandPrimary;
        icon = Icons.info_outline;
        break;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          content: Row(
            children: [
              Icon(icon, color: AppColors.textOnBrand, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textOnBrand,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
