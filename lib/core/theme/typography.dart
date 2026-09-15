import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const String fontFamily = 'Inter';

  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: Color(0xFF1A2332),
    height: 1.2,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Color(0xFF1A2332),
    height: 1.3,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Color(0xFF1A2332),
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Color(0xFF1A2332),
    height: 1.5,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFF1A2332),
    height: 1.5,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Color(0xFF6B7280),
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Color(0xFF6B7280),
    height: 1.4,
  );

  static const TextStyle kpiNumber = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: Color(0xFF1A2332),
    height: 1.1,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle tableHeader = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Color(0xFF6B7280),
    height: 1.4,
    letterSpacing: 0.2,
  );
}
