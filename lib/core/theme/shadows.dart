import 'package:flutter/material.dart';

/// SteryMed uses very soft shadows. Most cards rely on borders, not elevation.
abstract final class AppShadows {
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A1A2332), blurRadius: 8, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(color: Color(0x141A2332), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> modal = [
    BoxShadow(color: Color(0x1F1A2332), blurRadius: 24, offset: Offset(0, 8)),
  ];
}
