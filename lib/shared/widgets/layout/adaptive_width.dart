import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// Keeps the app at a readable width on wide screens (tablets, foldables,
/// landscape): content is centred on the page colour instead of stretching
/// edge to edge. On a phone (narrower than [maxWidth]) it changes nothing.
class AdaptiveWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AdaptiveWidth({super.key, required this.child, this.maxWidth = 760});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) return child;
        return ColoredBox(
          color: AppColors.backgroundApp,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
