import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class IconActionButton extends StatelessWidget {
  const IconActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(icon, size: 20, color: color ?? AppColors.textPrimary),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}
