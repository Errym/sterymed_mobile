import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class AppAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final Color? background;
  final Color? foreground;

  const AppAvatar({
    super.key,
    required this.initials,
    this.size = 40,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? AppColors.brandPrimaryLight,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials.toUpperCase(),
        style: AppTypography.bodyStrong.copyWith(
          color: foreground ?? AppColors.brandPrimary,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
