import 'package:flutter/material.dart';

import 'light_theme.dart';

/// Dark mode is deferred to v1.1.
/// For now, reuse the light theme so nothing breaks at runtime.
ThemeData buildDarkTheme() => buildLightTheme();
