import 'package:flutter/material.dart';

/// Depth is a soft, cool diffusion instead of hard borders: cards float a
/// couple of pixels above the page, sheets and modals float higher.
abstract final class AppShadows {
  static const List<BoxShadow> none = [];

  /// A card at rest.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A12284B),
      blurRadius: 8,
      spreadRadius: -2,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0F12284B),
      blurRadius: 16,
      spreadRadius: -4,
      offset: Offset(0, 6),
    ),
  ];

  /// A card that is being lifted (pressed, selected, featured).
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x1A12284B),
      blurRadius: 32,
      spreadRadius: -8,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x0A12284B),
      blurRadius: 12,
      spreadRadius: -2,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> modal = [
    BoxShadow(color: Color(0x1F12284B), blurRadius: 24, offset: Offset(0, 8)),
  ];
}
