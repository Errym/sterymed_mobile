import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class DeviceField extends StatelessWidget {
  final String label;
  final String? value;
  const DeviceField({super.key, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.label)),
          Text(
            value ?? '—',
            style: AppTypography.bodyStrong.copyWith(
              color: value == null
                  ? AppColors.textTertiary
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
