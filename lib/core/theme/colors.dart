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
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
  static const textOnBrand = Color(0xFFFFFFFF);

  static const borderLight = Color(0xFFE5E9F0);
  static const borderMedium = Color(0xFFD1D9E6);

  static const backgroundApp = Color(0xFFF7F9FC);
  static const backgroundSubtle = Color(0xFFF7F9FC);
  static const backgroundCard = Color(0xFFFFFFFF);
  static const backgroundMuted = Color(0xFFF1F4F9);

  // ── Status ─────────────────────────────────────────────────────
  static const success = Color(0xFF22A06B);
  static const successLight = Color(0xFFE6F4ED);

  static const warning = Color(0xFFE8A020);
  static const warningLight = Color(0xFFFDF3E1);

  static const danger = Color(0xFFD9544F);
  static const dangerLight = Color(0xFFFBE9E8);

  static const info = Color(0xFF3B82F6);
  static const infoLight = Color(0xFFE8F0FE);

  // ── Aging badges ───────────────────────────────────────────────
  static const agingFresh = Color(0xFF22A06B); // 0-7 days
  static const agingMedium = Color(0xFFE8A020); // 8-14 days
  static const agingUrgent = Color(0xFFD9544F); // 15+ days

  // ── Overlays ───────────────────────────────────────────────────
  static const overlayScrim = Color(0x66000000);
  static const overlayLight = Color(0x0D000000);
}
