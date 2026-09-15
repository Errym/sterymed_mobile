import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNav;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNav,
    this.floatingActionButton,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.backgroundApp,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNav,
      floatingActionButton: floatingActionButton,
    );
  }
}
