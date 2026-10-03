import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class FilterChipRow<T> extends StatelessWidget {
  final List<FilterChipOption<T>> options;
  final T? selected;
  final ValueChanged<T?> onSelected;

  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) {
          final o = options[i];
          // `selected` may be null and `o.value` may also be null
          // (the "Tous" chip). Use `==` — in Dart, null == null is true,
          // and null == 'x' is false. This is the correct behaviour.
          final isSelected = o.value == selected;
          final fg = isSelected ? AppColors.textOnBrand : AppColors.textSecondary;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(o.value),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.navyHeader
                      : AppColors.backgroundMuted,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (o.icon != null) ...[
                      Icon(o.icon, size: 15, color: fg),
                      const SizedBox(width: 6),
                    ] else if (o.dotColor != null) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: o.dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      o.label,
                      style: AppTypography.bodyStrong.copyWith(
                        color: fg,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class FilterChipOption<T> {
  final T? value;
  final String label;

  /// A small leading icon, or a coloured dot, to make the chip readable at a
  /// glance ("Stock bas" with a red dot).
  final IconData? icon;
  final Color? dotColor;
  const FilterChipOption({
    required this.value,
    required this.label,
    this.icon,
    this.dotColor,
  });
}
