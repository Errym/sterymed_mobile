import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class MetadataRow extends StatelessWidget {
  final String label;
  final String value;

  const MetadataRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTypography.caption),
          ),
          Text(
            value,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
