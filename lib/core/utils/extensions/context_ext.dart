import 'package:flutter/material.dart';

extension BuildContextX on BuildContext {
  Size get screenSize => MediaQuery.of(this).size;
  bool get isTablet => screenSize.width >= 700;
  void unfocus() => FocusScope.of(this).unfocus();
}
