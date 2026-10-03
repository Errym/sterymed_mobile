import 'package:flutter/material.dart';

/// SteryMed brand palette.
/// Tokens match the pilot UI mockups:
///   - navy header background
///   - aging badges (green / amber / red)
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────
  static const brandPrimary = Color(0xFF1E5BA8);
  static const brandPrimaryDark = Color(0xFF0F3D7A);
  static const brandPrimaryHover = Color(0xFF174A85);
  static const brandPrimaryLight = Color(0xFFE8F0FA);
  static const brandPrimaryExtraLight = Color(0xFFF4F8FD);

  // ── Navy header (matches mockups) ──────────────────────────────
  static const navyHeader = Color(0xFF1A2A5C);
  static const navyHeaderDark = Color(0xFF111E44);
  static const navyHeaderText = Color(0xFFFFFFFF);
  static const navyHeaderSubtext = Color(0xFFB8C4E0);

  // ── Neutrals ───────────────────────────────────────────────────
  static const textPrimary = Color(0xFF1A2332);
  static const textSecondary = Color(0xFF525C6B);
  static const textTertiary = Color(0xFF5F6B7A);
  static const textOnBrand = Color(0xFFFFFFFF);

  static const borderLight = Color(0xFFE5E9F0);
  static const borderMedium = Color(0xFFD1D9E6);

  /// Barely-there rule for cards that rely on shadow for their edge.
  static const hairline = Color(0x0F12284B);

  /// Tinted well used for sub-panels inside a white card (key/value rows,
  /// the "stock restant" strip, a stat tile).
  static const surfaceWell = Color(0xFFF3F5F9);

  static const backgroundApp = Color(0xFFF7F9FC);
  static const backgroundSubtle = Color(0xFFF7F9FC);
  static const backgroundCard = Color(0xFFFFFFFF);
  static const backgroundMuted = Color(0xFFF1F4F9);

  // ── Status ─────────────────────────────────────────────────────
  static const success = Color(0xFF167A3E);
  static const successLight = Color(0xFFE6F4ED);

  static const warning = Color(0xFFE8A020);
  /// Amber as TEXT or as an icon that carries meaning: 5.6:1 on white and on
  /// the amber tint. [warning] itself is for fills and accent bars only.
  static const warningText = Color(0xFF9A4A0A);

  /// The colour to use when [c] is the colour of TEXT: amber (a fill colour)
  /// becomes its readable twin; every other colour is already readable.
  static Color text(Color c) => c == warning ? warningText : c;
  static const warningLight = Color(0xFFFDF3E1);

  static const danger = Color(0xFFC0392B);
  static const dangerLight = Color(0xFFFBE9E8);

  static const info = Color(0xFF1D63D1);
  static const infoLight = Color(0xFFE8F0FE);

  // ── Aging badges ───────────────────────────────────────────────
  // Tag colours (text on its own light tint), both above 4.5:1.
  static const tagPurple = Color(0xFF6D28D9);
  static const tagPurpleLight = Color(0xFFEDE9FE);
  static const tagOrange = Color(0xFFC2410C);
  static const tagOrangeLight = Color(0xFFFFEDD5);

  static const agingFresh = Color(0xFF167A3E); // 0-7 days
  static const agingMedium = Color(0xFFE8A020); // 8-14 days
  static const agingUrgent = Color(0xFFC0392B); // 15+ days

  // ── Overlays ───────────────────────────────────────────────────
  static const overlayScrim = Color(0x66000000);
  static const overlayLight = Color(0x0D000000);
}
