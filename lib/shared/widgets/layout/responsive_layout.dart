import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final double tabletBreakpoint;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.tabletBreakpoint = 700,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= tabletBreakpoint && tablet != null) return tablet!;
    return mobile;
  }
}
