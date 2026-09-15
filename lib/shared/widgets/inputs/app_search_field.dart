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
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      style: AppTypography.body,
      decoration: InputDecoration(
        hintText: hint ?? 'Rechercher...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: (controller?.text.isNotEmpty ?? false) && onClear != null
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClear,
              )
            : null,
      ),
    );
  }
}
