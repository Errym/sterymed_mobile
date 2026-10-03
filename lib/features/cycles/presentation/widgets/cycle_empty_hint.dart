import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class CycleEmptyHint extends StatelessWidget {
  final String text;
  const CycleEmptyHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(text, style: AppTypography.caption),
    );
  }
}

/// A section whose data could not be loaded. Deliberately different from
/// [CycleEmptyHint]: "could not load" must never read as "nothing recorded".
class CycleLoadFailedHint extends StatelessWidget {
  final String what;
  final String message;
  final VoidCallback? onRetry;
  const CycleLoadFailedHint({
    super.key,
    required this.what,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.warning, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$what : chargement impossible ($message).',
              style: AppTypography.caption.copyWith(color: AppColors.warning),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
