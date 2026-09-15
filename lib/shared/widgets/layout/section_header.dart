import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.sectionTitle)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
