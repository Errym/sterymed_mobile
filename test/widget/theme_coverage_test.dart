// Regression tripwire: fails if a future theme refactor drops one of the
// sections added to close the "Theme layer" gap (snackBar, dialog,
// listTile, icon, popupMenu, navigationBar, switch, checkbox, radio, text).

import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/theme/light_theme.dart';

void main() {
  final theme = buildLightTheme();

  group('theme coverage', () {
    test('snackBarTheme has a background color', () {
      expect(theme.snackBarTheme.backgroundColor, isNotNull);
    });

    test('dialogTheme has a shape', () {
      expect(theme.dialogTheme.shape, isNotNull);
    });

    test('popupMenuTheme has a shape', () {
      expect(theme.popupMenuTheme.shape, isNotNull);
    });

    test('switchTheme has a track color', () {
      expect(theme.switchTheme.trackColor, isNotNull);
    });

    test('listTileTheme has content padding', () {
      expect(theme.listTileTheme.contentPadding, isNotNull);
    });

    test('iconTheme has a color', () {
      expect(theme.iconTheme.color, isNotNull);
    });

    test('navigationBarTheme has an indicator color', () {
      expect(theme.navigationBarTheme.indicatorColor, isNotNull);
    });

    test('checkboxTheme has a fill color', () {
      expect(theme.checkboxTheme.fillColor, isNotNull);
    });

    test('radioTheme has a fill color', () {
      expect(theme.radioTheme.fillColor, isNotNull);
    });

    test('textTheme uses the app font family', () {
      expect(theme.textTheme.bodyLarge?.fontFamily, 'Inter');
    });
  });
}
