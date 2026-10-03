import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class AppSearchField extends StatelessWidget {
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;

  const AppSearchField({
    super.key,
    this.hint,
    this.controller,
    this.onChanged,
    this.onClear,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.control),
        boxShadow: AppShadows.card,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: autofocus,
        style: AppTypography.body,
        decoration: InputDecoration(
          hintText: hint ?? 'Rechercher...',
          hintStyle: AppTypography.body.copyWith(
            color: AppColors.textTertiary,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppColors.textSecondary,
          ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          suffixIcon: (controller?.text.isNotEmpty ?? false) && onClear != null
              ? IconButton(
                tooltip: 'Effacer la recherche',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                )
              : null,
        ),
      ),
    );
  }
}
