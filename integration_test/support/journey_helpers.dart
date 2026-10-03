// Helpers shared by the journeys in integration_test/journeys/. They run on top
// of web_env.dart (launch, sign in, server read-back) and add the few UI
// gestures every journey needs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'web_env.dart';

/// Scrolls [f] into view in the first scrollable, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await settle(tester, 0.3);
  await tester.tap(f);
}

/// Opens the date picker behind [field], types [date] (dd/MM/yyyy) in its text
/// mode and confirms. Typing is used because tapping a calendar cell depends on
/// which month the picker opens on.
Future<void> pickDate(WidgetTester tester, Finder field, DateTime date) async {
  await tapVisible(tester, field);
  await settle(tester, 1);
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await settle(tester, 0.5);
  await tester.enterText(
    find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    ),
    DateFormat('dd/MM/yyyy').format(date),
  );
  await tester.pump();
  await tester.tap(find.text('OK'));
  await settle(tester, 1);
}

/// Opens the source field of a stock form and picks the seeded lot.
Future<void> pickSeededLot(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('source_field')));
  await settle(tester, 1);
  await tester.tap(find.textContaining('Lot ${WebEnv.glovesLot}').last);
  await settle(tester, 1);
}

/// Looks up a field of the first row of a list endpoint whose [match] holds.
Future<Map> firstWhere(
  String path,
  bool Function(Map row) match,
) async {
  final body = await ServerApi.get(path);
  final rows = (body is Map ? body['data'] : body) as List;
  return rows.cast<Map>().firstWhere(match);
}
