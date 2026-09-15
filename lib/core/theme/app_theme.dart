import 'package:flutter/material.dart';

import 'light_theme.dart';
import 'dark_theme.dart';

/// Single entry point for themes.
abstract final class AppTheme {
  static ThemeData light() => buildLightTheme();
  static ThemeData dark() => buildDarkTheme();
}
