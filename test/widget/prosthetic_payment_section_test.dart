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
  double? totalAmount,
}) {
  // The payment block has grown (total, deposit, balance): give the test a
  // screen as tall as a phone's scrolled view instead of the 600px default.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
            totalAmount: totalAmount,
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
    testWidgets('shows the 3 switches and 3 amount fields, no read-only card',
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
      // Mirror of the clinical edit: a payment save carries only payment fields,
      // because the server rejects a patch mixing both permissions.
      const clinicalFields = [
        'practitioner_id',
        'laboratory_id',
        'impression_type',
        'work_type',
        'impression_date',
        'planned_placement_date',
        'priority',
        'notes',
        'internal_comments',
      ];
      for (final field in clinicalFields) {
        expect(saved!.containsKey(field), isFalse, reason: field);
      }
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

  group('French decimal input', () {
    testWidgets('a comma amount is saved as a number, not cleared', (
      tester,
    ) async {
      Map<String, dynamic>? saved;
      await _pump(
        tester,
        canEdit: true,
        busy: false,
        onSave: (m) => saved = m,
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '120,50');
      await tester.enterText(fields.at(2), '1 200,5');
      await tester.tap(find.text('Enregistrer le paiement'));
      await tester.pump();

      expect(saved?['deposit_amount'], 120.5);
      expect(saved?['remaining_balance'], 1200.5);
    });

    testWidgets('an unreadable amount is refused, never sent as null', (
      tester,
    ) async {
      var calls = 0;
      await _pump(
        tester,
        canEdit: true,
        busy: false,
        depositAmount: 50,
        onSave: (_) => calls++,
      );
      await tester.enterText(find.byType(TextField).at(1), '12a');
      await tester.tap(find.text('Enregistrer le paiement'));
      await tester.pump();

      expect(calls, 0);
      expect(find.text('Montant invalide (ex. 120,50).'), findsOneWidget);
    });
  });

  group('remaining balance recalculated live (brief §8)', () {
    testWidgets('typing a total and receiving the deposit updates the balance',
        (tester) async {
      Map<String, dynamic>? saved;
      await _pump(tester, canEdit: true, busy: false, onSave: (m) => saved = m);
      final fields = find.byType(TextField);

      await tester.enterText(fields.at(0), '1200,50');
      await tester.pump();
      expect(find.text('1200.50'), findsOneWidget, reason: 'nothing received yet');

      await tester.enterText(fields.at(1), '300,25');
      await tester.tap(find.text('Acompte reçu'));
      await tester.pump();
      expect(find.text('900.25'), findsOneWidget);

      final balance = tester.widget<AppTextField>(
        find.widgetWithText(AppTextField, 'Solde restant (€) — calculé'),
      );
      expect(balance.enabled, isFalse, reason: 'computed, not typed');

      await tester.tap(find.text('Enregistrer le paiement'));
      await tester.pump();
      expect(saved?['total_amount'], 1200.5);
      expect(saved?['deposit_amount'], 300.25);
      expect(saved!.containsKey('remaining_balance'), isFalse,
          reason: 'with a total the server derives the balance itself');
    });

    testWidgets('a malformed total blocks the save', (tester) async {
      var calls = 0;
      await _pump(tester, canEdit: true, busy: false, onSave: (_) => calls++);
      await tester.enterText(find.byType(TextField).at(0), 'abc');
      await tester.tap(find.text('Enregistrer le paiement'));
      await tester.pump();
      expect(calls, 0);
      expect(find.text('Montant invalide (ex. 120,50).'), findsOneWidget);
    });

    testWidgets('a negative amount is refused', (tester) async {
      var calls = 0;
      await _pump(tester, canEdit: true, busy: false, onSave: (_) => calls++);
      await tester.enterText(find.byType(TextField).at(1), '-5');
      await tester.tap(find.text('Enregistrer le paiement'));
      await tester.pump();
      expect(calls, 0);
    });

    test('previewBalance mirrors the server arithmetic', () {
      double? p(String total, String deposit, bool received, [bool done = false]) =>
          ProstheticPaymentSection.previewBalance(
            total: total,
            deposit: deposit,
            depositReceived: received,
            finalPaymentCompleted: done,
          );
      expect(p('1200,50', '300,25', true), 900.25);
      expect(p('1200,50', '300,25', false), 1200.5, reason: 'deposit not received');
      expect(p('100', '300', true), 0, reason: 'never negative');
      expect(p('500', '0', true, true), 0, reason: 'final payment done');
      expect(p('', '300', true), isNull, reason: 'no total: typed by hand');
      expect(p('abc', '300', true), isNull);
    });
  });
}
