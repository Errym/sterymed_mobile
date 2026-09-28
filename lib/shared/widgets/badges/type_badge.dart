import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

enum BadgeTone { blue, green, yellow, red, purple, orange, gray }

class TypeBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;

  const TypeBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.gray,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  (Color, Color) _colors(BadgeTone tone) {
    switch (tone) {
      case BadgeTone.blue:
        return (AppColors.infoLight, AppColors.info);
      case BadgeTone.green:
        return (AppColors.successLight, AppColors.success);
      case BadgeTone.yellow:
        return (AppColors.warningLight, AppColors.warning);
      case BadgeTone.red:
        return (AppColors.dangerLight, AppColors.danger);
      case BadgeTone.purple:
        // TODO(theme): no AppColors token for purple yet — add one
        // (e.g. tagPurple/tagPurpleLight) instead of hard-coding this pair.
        return (const Color(0xFFEDE9FE), const Color(0xFF7C3AED));
      case BadgeTone.orange:
        // TODO(theme): no AppColors token for orange yet — add one
        // (e.g. tagOrange/tagOrangeLight) instead of hard-coding this pair.
        return (const Color(0xFFFFEDD5), const Color(0xFFEA580C));
      case BadgeTone.gray:
        return (AppColors.backgroundMuted, AppColors.textSecondary);
    }
  }
}
