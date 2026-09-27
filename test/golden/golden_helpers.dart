import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixes the test surface to a reproducible size at a 1.0 device pixel
/// ratio, regardless of the host machine's default test window or display
/// scaling. No `golden_toolkit` dependency is used here (it isn't a
/// project dependency — see test/COVERAGE.md), so there is no bundled real
/// font loading either: flutter_test falls back to its own deterministic
/// test font, which renders every glyph far wider than the app's real
/// Material typeface. A true phone width (~390px) overflows several
/// screens under that fallback font even though they don't on a real
/// device — hence the oversized canvas below. These goldens are a real
/// regression check on layout structure and color, not on exact phone-
/// viewport framing or text glyph rendering.
Future<void> setGoldenSurfaceSize(
  WidgetTester tester, {
  double width = 800,
  double height = 1400,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
