import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/theme/tokens.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/widgets/prosthetic_case_tile.dart';
import 'package:steriymed_mobile/shared/widgets/badges/aging_badge.dart';

import '../fixtures/prosthetic_case_fixture.dart';
import '../helpers/pump_app.dart';

void main() {
  Color badgeTextColor(WidgetTester tester) {
    final badge = find.byType(AgingBadge);
    expect(badge, findsOneWidget);
    final text = tester.widget<Text>(
      find.descendant(of: badge, matching: find.byType(Text)),
    );
    return text.style!.color!;
  }

  Widget wrap(Widget child) => Material(child: child);

  testWidgets('5 days shows an AgingBadge in the fresh color', (
    tester,
  ) async {
    await pumpApp(
      tester,
      wrap(
        ProstheticCaseTile(
          item: buildProstheticCase(daysWaitingForPlacement: 5),
        ),
      ),
    );

    expect(badgeTextColor(tester), AppColors.agingFresh);
  });

  testWidgets('10 days shows an AgingBadge in the medium color', (
    tester,
  ) async {
    await pumpApp(
      tester,
      wrap(
        ProstheticCaseTile(
          item: buildProstheticCase(daysWaitingForPlacement: 10),
        ),
      ),
    );

    expect(badgeTextColor(tester), AppColors.agingMedium);
  });

  testWidgets('20 days shows an AgingBadge in the urgent color', (
    tester,
  ) async {
    await pumpApp(
      tester,
      wrap(
        ProstheticCaseTile(
          item: buildProstheticCase(daysWaitingForPlacement: 20),
        ),
      ),
    );

    expect(badgeTextColor(tester), AppColors.agingUrgent);
  });

  testWidgets('null days shows no AgingBadge', (tester) async {
    await pumpApp(
        tester, wrap(ProstheticCaseTile(item: buildProstheticCase())));

    expect(find.byType(AgingBadge), findsNothing);
  });
}
