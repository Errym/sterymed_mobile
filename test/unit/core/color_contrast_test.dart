// Text must be readable in bright clinic light: WCAG AA is 4.5:1 for normal
// text. This pins every text colour the app uses to that floor, on every
// surface it can appear on, so a future colour tweak cannot quietly break it.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/theme/colors.dart';

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double contrast(Color a, Color b) {
  final hi = math.max(_luminance(a), _luminance(b));
  final lo = math.min(_luminance(a), _luminance(b));
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const surfaces = {
    'card': AppColors.backgroundCard,
    'page': AppColors.backgroundApp,
    'well': AppColors.surfaceWell,
    'muted': AppColors.backgroundMuted,
  };

  group('text on every surface', () {
    final texts = {
      'textPrimary': AppColors.textPrimary,
      'textSecondary': AppColors.textSecondary,
      'textTertiary': AppColors.textTertiary,
      'brandPrimary': AppColors.brandPrimary,
      'success': AppColors.success,
      'danger': AppColors.danger,
      'info': AppColors.info,
      'warningText': AppColors.warningText,
    };
    for (final t in texts.entries) {
      for (final s in surfaces.entries) {
        test('${t.key} on ${s.key} is at least 4.5:1', () {
          expect(contrast(t.value, s.value), greaterThanOrEqualTo(4.5));
        });
      }
    }
  });

  group('badges: coloured text on its own light tint', () {
    final pairs = {
      'success': (AppColors.success, AppColors.successLight),
      'warning': (AppColors.warningText, AppColors.warningLight),
      'danger': (AppColors.danger, AppColors.dangerLight),
      'info': (AppColors.info, AppColors.infoLight),
      'purple tag': (AppColors.tagPurple, AppColors.tagPurpleLight),
      'orange tag': (AppColors.tagOrange, AppColors.tagOrangeLight),
    };
    for (final p in pairs.entries) {
      test(p.key, () {
        expect(contrast(p.value.$1, p.value.$2), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('white text on a coloured button or header', () {
    final fills = {
      'brandPrimary': AppColors.brandPrimary,
      'success': AppColors.success,
      'danger': AppColors.danger,
      'info': AppColors.info,
      'navyHeader': AppColors.navyHeader,
    };
    for (final f in fills.entries) {
      test(f.key, () {
        expect(contrast(AppColors.textOnBrand, f.value), greaterThanOrEqualTo(4.5));
      });
    }
  });

  test('amber is a fill colour; as text it always becomes its readable twin', () {
    expect(AppColors.text(AppColors.warning), AppColors.warningText);
    expect(AppColors.text(AppColors.danger), AppColors.danger);
    // The raw amber would fail, which is exactly why it is never used as text.
    expect(contrast(AppColors.warning, AppColors.backgroundCard), lessThan(4.5));
  });
}
