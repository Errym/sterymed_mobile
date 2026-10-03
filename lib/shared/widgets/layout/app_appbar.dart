import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../feedback/sync_status_pill.dart';

/// SteryMed AppBar: flat, on the page colour, title next to a back arrow.
/// Every screen uses the same bar so the app reads as one product; depth comes
/// from the cards below it, not from a coloured header.
///
/// [navy] is kept so existing call sites compile; it no longer changes the
/// look.
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
    return AppBar(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      backgroundColor: AppColors.backgroundApp,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      leading: leading ?? (showBack ? AppBackButton.maybe(context) : null),
      actions: [
        ...(actions ?? const <Widget>[]),
        const SyncStatusPill(),
        const SizedBox(width: AppSpacing.md),
      ],
    );
  }
}

/// The back arrow every screen above a tab shows. It pops when there is
/// history and otherwise goes to the tab the screen belongs to, so a person
/// who arrived by a deep link or a restored session is never stranded.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  /// The button when this screen needs one, else null (tab roots, which are
  /// reached by the bottom bar and have nothing "behind" them).
  static Widget? maybe(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return Navigator.of(context).canPop() ? const AppBackButton() : null;
    }
    final location =
        router.routerDelegate.currentConfiguration.uri.toString();
    if (!context.canPop() && isTabRoute(location)) return null;
    return const AppBackButton();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () {
        if (GoRouter.maybeOf(context) == null) {
          Navigator.of(context).maybePop();
        } else {
          context.popOrGo();
        }
      },
    );
  }
}
