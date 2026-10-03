// On a tablet the app keeps a readable width; on a phone nothing changes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/shared/widgets/layout/adaptive_width.dart';

Future<void> pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(
    home: AdaptiveWidth(child: SizedBox.expand(key: Key('content'))),
  ));
}

void main() {
  testWidgets('a phone gets the full width', (tester) async {
    await pump(tester, const Size(390, 844));
    expect(tester.getSize(find.byKey(const Key('content'))).width, 390);
  });

  testWidgets('a tablet gets a centred column of the maximum width', (tester) async {
    await pump(tester, const Size(1280, 800));
    final box = tester.getRect(find.byKey(const Key('content')));
    expect(box.width, 760);
    expect(box.center.dx, 640, reason: 'centred on the screen');
  });

  testWidgets('exactly the maximum width is not constrained', (tester) async {
    await pump(tester, const Size(760, 800));
    expect(tester.getSize(find.byKey(const Key('content'))).width, 760);
  });
}
