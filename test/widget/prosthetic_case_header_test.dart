// The prosthetic case header (brief §7-§9): the flow position, the aging of a
// returned case, and the NON-BLOCKING payment warning before placement.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_case_data.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/widgets/prosthetic_case_header.dart';

import '../fixtures/prosthetic_case_fixture.dart';
import '../helpers/pump_app.dart';

void main() {
  test('each status maps to its place in the brief\'s flow', () {
    expect(prostheticStageOf(ProstheticCaseStatus.impressionCompleted), 0);
    expect(prostheticStageOf(ProstheticCaseStatus.sentToLaboratory), 1);
    expect(prostheticStageOf(ProstheticCaseStatus.receivedAtPractice), 2);
    expect(prostheticStageOf(ProstheticCaseStatus.placementScheduled), 3);
    expect(prostheticStageOf(ProstheticCaseStatus.placed), 4);
    expect(prostheticStageOf(ProstheticCaseStatus.cancelled), isNull);
  });

  group('payment warning (never blocks, only before placement)', () {
    test('a balance still due before placement is flagged', () {
      final c = buildProstheticCase(
        status: ProstheticCaseStatus.placementScheduled,
        remainingBalance: 120.5,
      );
      expect(prostheticPaymentWarning(c), contains('À vérifier avant la pose'));
    });

    test('an unreceived deposit is flagged even with no balance figure', () {
      final c = buildProstheticCase(
        status: ProstheticCaseStatus.receivedAtPractice,
        depositRequested: true,
        depositReceived: false,
      );
      expect(prostheticPaymentWarning(c), contains('Acompte'));
    });

    test('nothing is said when all is paid, or once placed or cancelled', () {
      expect(
        prostheticPaymentWarning(buildProstheticCase(
            status: ProstheticCaseStatus.placementScheduled, remainingBalance: 0)),
        isNull,
      );
      for (final s in [
        ProstheticCaseStatus.impressionCompleted,
        ProstheticCaseStatus.sentToLaboratory,
        ProstheticCaseStatus.placed,
        ProstheticCaseStatus.cancelled,
      ]) {
        expect(prostheticPaymentWarning(buildProstheticCase(status: s, remainingBalance: 500)), isNull, reason: '$s');
      }
    });
  });

  group('the header', () {
    Future<void> pump(WidgetTester tester, ProstheticCaseData c,
        {Size? size, double scale = 1}) async {
      if (size != null) {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });
      }
      await pumpApp(tester, Scaffold(body: SingleChildScrollView(child: ProstheticCaseHeader(data: c))));
      await tester.pumpAndSettle();
    }

    testWidgets('a returned, not-yet-placed case shows its waiting days and the balance',
        (tester) async {
      await pump(
        tester,
        buildProstheticCase(
          status: ProstheticCaseStatus.receivedAtPractice,
          laboratoryName: 'Labo Dentaire Sud',
          daysWaitingForPlacement: 12,
          remainingBalance: 80,
        ),
      );
      expect(find.byKey(const Key('prosthetic-stepper')), findsOneWidget);
      expect(find.byKey(const Key('prosthetic-aging')), findsOneWidget);
      expect(find.byKey(const Key('prosthetic-payment-warning')), findsOneWidget);
      expect(find.text('Labo Dentaire Sud'), findsOneWidget);
    });

    testWidgets('a cancelled case says so and has no flow or aging', (tester) async {
      await pump(
        tester,
        buildProstheticCase(status: ProstheticCaseStatus.cancelled, daysWaitingForPlacement: 30),
      );
      expect(find.byKey(const Key('prosthetic-cancelled')), findsOneWidget);
      expect(find.byKey(const Key('prosthetic-stepper')), findsNothing);
      expect(find.byKey(const Key('prosthetic-aging')), findsNothing);
    });

    testWidgets('a placed case shows no aging and no payment warning', (tester) async {
      await pump(
        tester,
        buildProstheticCase(
          status: ProstheticCaseStatus.placed,
          daysWaitingForPlacement: 9,
          remainingBalance: 50,
        ),
      );
      expect(find.byKey(const Key('prosthetic-aging')), findsNothing);
      expect(find.byKey(const Key('prosthetic-payment-warning')), findsNothing);
    });

    testWidgets('missing lab, date and balance are dashes, never zero', (tester) async {
      await pump(tester, buildProstheticCase());
      expect(find.text('—'), findsNWidgets(3));
    });

    for (final s in const [(Size(320, 568), 1.3), (Size(390, 844), 1.0), (Size(1024, 768), 1.0)]) {
      testWidgets('does not overflow at ${s.$1} x${s.$2}', (tester) async {
        await pump(
          tester,
          buildProstheticCase(
            status: ProstheticCaseStatus.placementScheduled,
            practitionerName: 'Docteur Prénom-Composé Nom-Très-Long',
            laboratoryName: 'Laboratoire Dentaire du Centre-Ville de Paris Huitième',
            daysWaitingForPlacement: 21,
            remainingBalance: 1234.5,
            plannedPlacementDate: DateTime(2026, 11, 3),
          ),
          size: s.$1,
          scale: s.$2,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
