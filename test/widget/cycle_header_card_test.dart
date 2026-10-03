// The cycle detail header: where the cycle stands in the flow, what to do
// next for THIS role, and how long it ran. Wrong guidance here (telling a
// viewer to release a cycle, or hiding that a cycle was rejected) is a
// clinical-safety problem, not a cosmetic one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/features/cycles/data/models/cycle_data.dart';
import 'package:steriymed_mobile/features/cycles/presentation/widgets/cycle_header_card.dart';

import '../helpers/pump_app.dart';

CycleData cycle(
  String status, {
  DateTime? started,
  DateTime? completed,
  String device = 'Autoclave A1',
  String? operator = 'Alice Dupont',
}) =>
    CycleData(
      id: 'c1',
      number: '12',
      status: status,
      deviceId: 'd1',
      deviceName: device,
      programTemperatureCelsius: 134,
      programPlateauMinutes: 18,
      operatorName: operator,
      createdAt: DateTime(2026, 10, 3, 8),
      startedAt: started,
      completedAt: completed,
    );

void main() {
  group('stage and duration', () {
    test('every status maps to its place in the flow', () {
      expect(cycleStageOf('created'), 0);
      expect(cycleStageOf('in_progress'), 1);
      expect(cycleStageOf('completed'), 2);
      expect(cycleStageOf('awaiting_release'), 3);
      expect(cycleStageOf('released'), 4);
      expect(cycleStageOf('rejected'), 4);
      expect(cycleStageOf('something_new'), 0);
    });

    test('duration reads like a person would say it', () {
      final start = DateTime(2026, 10, 3, 8);
      expect(cycleDuration(cycle('created')), '—');
      expect(cycleDuration(cycle('completed', started: start, completed: start.add(const Duration(seconds: 30)))), '< 1 min');
      expect(cycleDuration(cycle('completed', started: start, completed: start.add(const Duration(minutes: 45)))), '45 min');
      expect(cycleDuration(cycle('completed', started: start, completed: start.add(const Duration(hours: 1, minutes: 12)))), '1 h 12');
      expect(cycleDuration(cycle('completed', started: start, completed: start.add(const Duration(hours: 2)))), '2 h');
      // Still running: measured up to "now".
      expect(
        cycleDuration(cycle('in_progress', started: start), now: start.add(const Duration(minutes: 20))),
        '20 min',
      );
    });
  });

  group('next step depends on the role', () {
    test('only someone who can release is told to decide', () {
      expect(cycleNextStep('awaiting_release', canManage: true, canRelease: true), contains('à vous de libérer'));
      final viewer = cycleNextStep('awaiting_release', canManage: false, canRelease: false);
      expect(viewer, contains('En attente'));
      expect(viewer, isNot(contains('à vous')));
    });

    test('only someone who can manage is told to act on a running cycle', () {
      expect(cycleNextStep('created', canManage: true, canRelease: false), contains('démarrez'));
      expect(cycleNextStep('created', canManage: false, canRelease: false), isNot(contains('démarrez')));
      expect(cycleNextStep('completed', canManage: true, canRelease: false), contains('tests de contrôle'));
    });

    test('a rejected cycle says no label can be issued', () {
      expect(cycleNextStep('rejected', canManage: true, canRelease: true), contains('aucune étiquette'));
    });
  });

  group('the card', () {
    Future<void> pump(WidgetTester tester, CycleData c,
        {bool manage = true, bool release = false, Size? size, double scale = 1}) async {
      if (size != null) {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });
      }
      await pumpApp(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: CycleHeaderCard(cycle: c, canManage: manage, canRelease: release),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the device, number, figures, stepper and next step',
        (tester) async {
      final start = DateTime(2026, 10, 3, 8);
      await pump(
        tester,
        cycle('awaiting_release', started: start, completed: start.add(const Duration(minutes: 50))),
        release: true,
      );
      expect(find.text('AUTOCLAVE A1'), findsOneWidget);
      expect(find.text('Cycle 12'), findsOneWidget);
      expect(find.text('134 °C · 18 min'), findsOneWidget);
      expect(find.text('50 min'), findsOneWidget);
      expect(find.text('Alice Dupont'), findsOneWidget);
      expect(find.byKey(const Key('cycle-stepper')), findsOneWidget);
      expect(find.textContaining('à vous de libérer'), findsOneWidget);
    });

    testWidgets('a rejected cycle shows the closing step as Rejeté', (tester) async {
      await pump(tester, cycle('rejected', started: DateTime(2026, 10, 3, 8)));
      expect(find.text('Rejeté'), findsWidgets);
      expect(find.textContaining('aucune étiquette'), findsOneWidget);
    });

    testWidgets('failed control tests are announced, and only then', (tester) async {
      await pumpApp(tester, Scaffold(body: SingleChildScrollView(child: CycleHeaderCard(
        cycle: cycle('awaiting_release'), canManage: true, canRelease: true, failedTests: 2))));
      await tester.pumpAndSettle();
      expect(find.text('2 tests de contrôle ont échoué sur ce cycle.'), findsOneWidget);

      await pumpApp(tester, Scaffold(body: SingleChildScrollView(child: CycleHeaderCard(
        cycle: cycle('awaiting_release'), canManage: true, canRelease: true))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cycle-failed-tests')), findsNothing);
    });

    testWidgets('missing data is a dash, never a zero or an empty gap',
        (tester) async {
      await pump(tester, cycle('created', operator: null));
      expect(find.text('—'), findsWidgets);
    });

    for (final s in const [(Size(320, 568), 1.3), (Size(390, 844), 1.0), (Size(1024, 768), 1.0)]) {
      testWidgets('does not overflow at ${s.$1} x${s.$2}', (tester) async {
        await rootBundle.load('assets/fonts/Inter-Regular.ttf');
        await pump(
          tester,
          cycle('awaiting_release',
              started: DateTime(2026, 10, 3, 8),
              completed: DateTime(2026, 10, 3, 9, 12),
              device: 'Autoclave Melag Vacuklav 40B+ — salle de stérilisation principale',
              operator: 'Docteur Prénom-Composé Nom-Très-Long'),
          release: true,
          size: s.$1,
          scale: s.$2,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
