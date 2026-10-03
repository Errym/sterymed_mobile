// Phase 4 (C07): a non-conformity recalls labels and quarantines batches, so it
// is confirmed first; a label is reported by the id its code carries (a
// recalled or expired label can still be reported); older cycles are reachable.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/features/compliance/data/models/non_conformity_data.dart';
import 'package:steriymed_mobile/features/compliance/data/repositories/non_conformity_repository.dart';
import 'package:steriymed_mobile/features/compliance/presentation/widgets/nc_create_sheet.dart';
import 'package:steriymed_mobile/features/cycles/data/models/cycle_data.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/cycle_repository.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_repository.dart';

import '../helpers/pump_app.dart';

class _Cycles extends Mock implements CycleRepository {}

class _Labels extends Mock implements LabelRepository {}

class _Ncs extends Mock implements NonConformityRepository {}

CycleData _cycle(int n) => CycleData(
  id: 'cycle-$n',
  number: 'CT-$n',
  status: 'released',
  deviceId: 'd1',
  deviceName: 'Autoclave A',
  createdAt: DateTime(2026, 9, n.clamp(1, 28)),
);

const _labelId = '0199aaaa-bbbb-7ccc-8ddd-eeeeeeeeeeee';

void main() {
  late _Cycles cycles;
  late _Labels labels;
  late _Ncs ncs;

  setUp(() {
    cycles = _Cycles();
    labels = _Labels();
    ncs = _Ncs();
    when(
      () => cycles.list(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer(
      (_) async => CursorPage(items: [_cycle(30)], nextCursor: 'next-page'),
    );
    when(
      () => cycles.loadMore('next-page'),
    ).thenAnswer((_) async => CursorPage(items: [_cycle(2)]));
    final di = GetIt.instance;
    if (di.isRegistered<CycleRepository>()) di.unregister<CycleRepository>();
    if (di.isRegistered<LabelRepository>()) di.unregister<LabelRepository>();
    if (di.isRegistered<NonConformityRepository>()) {
      di.unregister<NonConformityRepository>();
    }
    di
      ..registerSingleton<CycleRepository>(cycles)
      ..registerSingleton<LabelRepository>(labels)
      ..registerSingleton<NonConformityRepository>(ncs);
  });

  tearDown(() {
    GetIt.instance.unregister<CycleRepository>();
    GetIt.instance.unregister<LabelRepository>();
    GetIt.instance.unregister<NonConformityRepository>();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, const Scaffold(body: NcCreateSheet()));
    await tester.pumpAndSettle();
  }

  testWidgets('an older cycle can be reached with "plus anciens"', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Charger les cycles plus anciens'), findsOneWidget);

    await tester.tap(find.text('Charger les cycles plus anciens'));
    await tester.pumpAndSettle();

    verify(() => cycles.loadMore('next-page')).called(1);
    expect(find.text('Charger les cycles plus anciens'), findsNothing);
  });

  testWidgets('reporting a label uses the id in its code, with no lookup, '
      'after an explicit confirmation', (tester) async {
    when(
      () => ncs.create(
        subjectType: any(named: 'subjectType'),
        subjectId: any(named: 'subjectId'),
        description: any(named: 'description'),
      ),
    ).thenAnswer(
      (_) async => NonConformityData(
        id: 'nc1',
        subjectType: 'label',
        subjectId: _labelId,
        description: 'x',
        raisedByUserId: 'u1',
        raisedAt: DateTime(2026, 10, 1),
      ),
    );
    await open(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Étiquette').last);
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'urn:steriqore:label:$_labelId');
    await tester.enterText(fields.at(1), 'Pochette percée');
    await tester.tap(find.text('Enregistrer la non-conformité'));
    await tester.pumpAndSettle();

    // Nothing is sent until the consequence is accepted.
    verifyNever(
      () => ncs.create(
        subjectType: any(named: 'subjectType'),
        subjectId: any(named: 'subjectId'),
        description: any(named: 'description'),
      ),
    );
    expect(find.textContaining('rappelée'), findsWidgets);

    await tester.tap(find.text('Déclarer'));
    await tester.pumpAndSettle();

    verifyNever(() => labels.getByCode(any()));
    verify(
      () => ncs.create(
        subjectType: 'label',
        subjectId: _labelId,
        description: 'Pochette percée',
      ),
    ).called(1);
  });

  testWidgets('declining the confirmation sends nothing', (tester) async {
    await open(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Étiquette').last);
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), _labelId);
    await tester.enterText(fields.at(1), 'Erreur');
    await tester.tap(find.text('Enregistrer la non-conformité'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    verifyNever(
      () => ncs.create(
        subjectType: any(named: 'subjectType'),
        subjectId: any(named: 'subjectId'),
        description: any(named: 'description'),
      ),
    );
  });
}
