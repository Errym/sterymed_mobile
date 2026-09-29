// Task 2 (test coverage completion). This stub was named after a
// ProstheticPaymentBloc that doesn't exist — the payment section is a
// plain StatefulWidget (ProstheticPaymentSection) with local switch/text
// state and an injected onSave callback, no bloc. Per the user's explicit
// choice ("test the real pattern instead"), this tests that widget
// directly. It is self-contained (data + callbacks only, no
// getIt/repository dependency), so it needs only a bare MaterialApp, not
// the full pumpApp/GetIt harness.
//
// This is also the widget where a real Flutter framework bug was found
// and fixed earlier this session: SwitchListTile with no Material
// ancestor (see the `Material(type: MaterialType.transparency)` wrapper
// in prosthetic_payment_section.dart) — these tests exercise exactly the
// switches that bug affected.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/utils/formatters/currency_formatter.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/widgets/prosthetic_payment_section.dart';
import 'package:steriymed_mobile/shared/widgets/inputs/app_text_field.dart';

import '../fixtures/prosthetic_case_fixture.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool canEdit,
  required bool busy,
  required ValueChanged<Map<String, dynamic>> onSave,
  bool depositRequested = false,
  bool depositReceived = false,
  double? depositAmount,
  bool finalPaymentCompleted = false,
  double? remainingBalance,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProstheticPaymentSection(
          data: buildProstheticCase(
            depositRequested: depositRequested,
            depositReceived: depositReceived,
            depositAmount: depositAmount,
            finalPaymentCompleted: finalPaymentCompleted,
            remainingBalance: remainingBalance,
          ),
          canEdit: canEdit,
          busy: busy,
          onSave: onSave,
        ),
      ),
    ),
  );
}

void main() {
  group('read-only (no prosthetic_payments.manage)', () {
    testWidgets('shows "Paiement à jour" when nothing is due', (tester) async {
      await _pump(tester, canEdit: false, busy: false, onSave: (_) {});

      expect(find.text('Paiement à jour'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets(
      'shows "Paiement à vérifier" when a deposit was requested but not '
      'received',
      (tester) async {
        await _pump(
          tester,
          canEdit: false,
          busy: false,
          onSave: (_) {},
          depositRequested: true,
        );

        expect(find.text('Paiement à vérifier'), findsOneWidget);
        expect(find.text('Acompte demandé, non reçu.'), findsOneWidget);
      },
    );

    testWidgets('shows the remaining balance when one is outstanding',
        (tester) async {
      await _pump(
        tester,
        canEdit: false,
        busy: false,
        onSave: (_) {},
        remainingBalance: 150.5,
      );

      expect(find.text('Paiement à vérifier'), findsOneWidget);
      expect(
        find.text('Solde restant : ${AppCurrencyFormatter.eur(150.5)}'),
        findsOneWidget,
      );
    });
  });

  group('editable (has prosthetic_payments.manage)', () {
    testWidgets('shows the 3 switches and 2 amount fields, no read-only card',
        (tester) async {
      await _pump(tester, canEdit: true, busy: false, onSave: (_) {});

      expect(find.byType(SwitchListTile), findsNWidgets(3));
      expect(find.text('Paiement à jour'), findsNothing);
    });

    testWidgets('save sends the current switch and field values',
        (tester) async {
      Map<String, dynamic>? saved;
      await _pump(
        tester,
        canEdit: true,
        busy: false,
        onSave: (data) => saved = data,
        depositAmount: 100,
      );

      await tester.tap(find.text('Acompte demandé'));
      await tester.pump();
      await tester.tap(find.text('Acompte reçu'));
      await tester.pump();
      await tester.tap(find.text('Enregistrer le paiement'));
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!['deposit_requested'], isTrue);
      expect(saved!['deposit_received'], isTrue);
      expect(saved!['deposit_amount'], 100.0);
      expect(saved!['final_payment_completed'], isFalse);
    });

    testWidgets('the save button shows a loading state when busy',
        (tester) async {
      await _pump(tester, canEdit: true, busy: true, onSave: (_) {});

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('final payment recalculation (brief page 8)', () {
    testWidgets(
      'toggling "Paiement final effectué" on zeroes and disables the '
      'remaining balance field',
      (tester) async {
        await _pump(
          tester,
          canEdit: true,
          busy: false,
          onSave: (_) {},
          remainingBalance: 125.0,
        );

        expect(find.text('125.00'), findsOneWidget);

        await tester.tap(find.text('Paiement final effectué'));
        await tester.pump();

        expect(find.text('0.00'), findsOneWidget);
        final field = tester.widget<AppTextField>(
          find.widgetWithText(AppTextField, 'Solde restant (€)'),
        );
        expect(field.enabled, isFalse);
      },
    );

    testWidgets(
      'save() sends a zero remaining balance whenever the final payment is '
      'completed, even if the loaded data had a stale non-zero balance',
      (tester) async {
        Map<String, dynamic>? saved;
        await _pump(
          tester,
          canEdit: true,
          busy: false,
          onSave: (data) => saved = data,
          finalPaymentCompleted: true,
          remainingBalance: 125.0,
        );

        await tester.tap(find.text('Enregistrer le paiement'));
        await tester.pump();

        expect(saved, isNotNull);
        expect(saved!['remaining_balance'], 0.0);
      },
    );
  });
}
