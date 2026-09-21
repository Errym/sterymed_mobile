import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../../../core/theme/tokens.dart';

/// SteryMed AppBar.
/// Two modes:
///   - [navy]=true  → deep navy header (mockup language, used on list/detail screens)
///   - [navy]=false → white header (used on form screens)
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final bool navy;

  const AppAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBack = true,
    this.navy = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final bg = navy ? AppColors.navyHeader : AppColors.backgroundApp;
    final fg = navy ? AppColors.navyHeaderText : AppColors.textPrimary;

    return AppBar(
      title: Text(title),
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: navy
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            )
          : null,
      leading: leading ??
          (showBack && Navigator.of(context).canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null),
      actions: actions,
      bottom: navy
          ? null
          : const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: AppColors.borderLight),
            ),
    );
  }
}
