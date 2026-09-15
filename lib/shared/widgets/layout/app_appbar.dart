import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;

  const AppAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBack = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading:
          leading ??
          (showBack && Navigator.of(context).canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null),
      actions: actions,
      backgroundColor: AppColors.backgroundApp,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.borderLight),
      ),
    );
  }
}
