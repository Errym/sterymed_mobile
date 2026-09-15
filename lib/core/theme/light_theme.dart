import 'package:flutter/material.dart';

import 'colors.dart';
import 'radius.dart';
import 'typography.dart';

ThemeData buildLightTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.brandPrimary,
    onPrimary: AppColors.textOnBrand,
    secondary: AppColors.brandPrimaryDark,
    onSecondary: AppColors.textOnBrand,
    error: AppColors.danger,
    onError: AppColors.textOnBrand,
    surface: AppColors.backgroundCard,
    onSurface: AppColors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.backgroundApp,
    fontFamily: AppTypography.fontFamily,

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.backgroundApp,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: AppTypography.sectionTitle,
    ),

    cardTheme: CardThemeData(
      color: AppColors.backgroundCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.borderLight),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.borderLight,
      thickness: 1,
      space: 1,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.backgroundSubtle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
      labelStyle: AppTypography.label,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.textOnBrand,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: AppTypography.buttonLabel,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brandPrimary,
        textStyle: AppTypography.buttonLabel,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.borderMedium),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: AppTypography.buttonLabel,
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.backgroundApp,
      selectedItemColor: AppColors.brandPrimary,
      unselectedItemColor: AppColors.textSecondary,
      selectedLabelStyle: AppTypography.caption,
      unselectedLabelStyle: AppTypography.caption,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.backgroundSubtle,
      labelStyle: AppTypography.label,
      side: const BorderSide(color: AppColors.borderLight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    ),
  );
}
