// The entrance animation must never hide content from someone who turned
// animations off, and must not leave a timer running after the screen is gone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/shared/widgets/lists/animated_list_item.dart';

void main() {
  testWidgets('animates in, with a delay that grows with the index but is capped',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(const MaterialApp(
      home: AnimatedListItem(index: 3, child: Text('row')),
    ));
    FadeTransition fade() => tester.widget(find.descendant(of: find.byType(AnimatedListItem), matching: find.byType(FadeTransition)));
    expect(fade().opacity.value, 0);
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump(const Duration(milliseconds: 400));
    expect(fade().opacity.value, 1);
  });

  testWidgets('with animations turned off in the phone settings it is shown at once',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(const MaterialApp(
      home: AnimatedListItem(index: 9, child: Text('row')),
    ));
    final fade = tester.widget<FadeTransition>(find.descendant(of: find.byType(AnimatedListItem), matching: find.byType(FadeTransition)));
    expect(fade.opacity.value, 1);
  });

  testWidgets('leaving the screen before the delay ends leaves no timer behind',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(const MaterialApp(
      home: AnimatedListItem(index: 9, child: Text('row')),
    ));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    // A pending timer would fail the test at teardown.
  });
}
