import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../buttons/primary_button.dart';

class ErrorView extends StatelessWidget {
  final String message;
  final String? requestId;
  final VoidCallback? onRetry;

  const ErrorView({
    super.key,
    required this.message,
    this.requestId,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
            if (requestId != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'ID: $requestId',
                textAlign: TextAlign.center,
                style: AppTypography.caption,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Réessayer',
                onPressed: onRetry,
                icon: Icons.refresh,
                isFullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
