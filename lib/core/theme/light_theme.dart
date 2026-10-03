import 'package:flutter/material.dart';

import 'colors.dart';
import 'radius.dart';
import 'spacing.dart';
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
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: AppSpacing.xxs,
      titleTextStyle: AppTypography.sectionTitle,
    ),

    cardTheme: CardThemeData(
      color: AppColors.backgroundCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.hairline),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
      labelStyle: AppTypography.label,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.textOnBrand,
        elevation: 0,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
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
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
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

    // Default snackbar look. `AppSnackbar.show` only overrides the
    // background color per [SnackKind] on top of this.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.brandPrimary,
      behavior: SnackBarBehavior.floating,
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      contentTextStyle: AppTypography.body.copyWith(
        color: AppColors.textOnBrand,
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      titleTextStyle: AppTypography.sectionTitle,
      contentTextStyle: AppTypography.body,
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      titleTextStyle: AppTypography.bodyStrong,
      subtitleTextStyle: AppTypography.caption,
      iconColor: AppColors.textSecondary,
    ),

    iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 20),
    primaryIconTheme: const IconThemeData(
      color: AppColors.textPrimary,
      size: 20,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      textStyle: AppTypography.body,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.backgroundApp,
      indicatorColor: AppColors.brandPrimaryLight,
      labelTextStyle: WidgetStateProperty.all(AppTypography.caption),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.brandPrimary
              : AppColors.textSecondary,
        ),
      ),
    ),

    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.brandPrimary
            : AppColors.borderMedium,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.brandPrimary
            : AppColors.backgroundCard,
      ),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.brandPrimary
            : null,
      ),
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.brandPrimary
            : null,
      ),
    ),

    textTheme: const TextTheme(
      displayLarge: AppTypography.pageTitle,
      titleLarge: AppTypography.sectionTitle,
      titleMedium: AppTypography.cardTitle,
      bodyLarge: AppTypography.body,
      bodyMedium: AppTypography.body,
      bodySmall: AppTypography.caption,
      labelLarge: AppTypography.buttonLabel,
      labelMedium: AppTypography.label,
      labelSmall: AppTypography.caption,
    ),
  );
}
