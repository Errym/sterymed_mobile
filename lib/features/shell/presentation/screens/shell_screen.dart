import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../widgets/bottom_nav_bar.dart';

class ShellScreen extends StatelessWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: child,
      bottomNavigationBar: BottomNavBar(currentLocation: location),
    );
  }
}
