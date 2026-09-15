import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/tokens.dart';

class CopyableText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const CopyableText({super.key, required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copié'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: style ?? AppTypography.body),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.copy, size: 14, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
