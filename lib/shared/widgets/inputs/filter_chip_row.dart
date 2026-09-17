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
          final isSelected = o.value == selected;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(o.value),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.brandPrimary
                      : AppColors.backgroundSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.borderLight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  o.label,
                  style: AppTypography.bodyStrong.copyWith(
                    color: isSelected
                        ? AppColors.textOnBrand
                        : AppColors.textSecondary,
                    fontSize: 13,
                  ),
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
  const FilterChipOption({required this.value, required this.label});
}
