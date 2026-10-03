// Phase 3 (R04): a saved selection must stay visible after its target is
// archived; dropping it blanks the field and silently unassigns on save.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/laboratory_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/repositories/prosthetic_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/widgets/prosthetic_case_edit_sheet.dart';

import '../fixtures/prosthetic_case_fixture.dart';
import '../helpers/pump_app.dart';

class _MockRepo extends Mock implements ProstheticRepository {}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(
      () => repo.listLaboratories(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer(
      (_) async => const [
        LaboratoryData(id: 'lab-live', name: 'Labo Actif'),
        LaboratoryData(id: 'lab-old', name: 'Labo Ancien', archived: true),
        LaboratoryData(id: 'lab-other', name: 'Labo Autre', archived: true),
      ],
    );
    if (GetIt.instance.isRegistered<ProstheticRepository>()) {
      GetIt.instance.unregister<ProstheticRepository>();
    }
    GetIt.instance.registerSingleton<ProstheticRepository>(repo);
  });

  tearDown(() => GetIt.instance.unregister<ProstheticRepository>());

  testWidgets('the current laboratory stays selectable once archived', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      Scaffold(
        body: ProstheticCaseEditSheet(
          caseData: buildProstheticCase(
            laboratoryId: 'lab-old',
            laboratoryName: 'Labo Ancien',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The saved (archived) lab is shown as the field's value.
    expect(find.text('Labo Ancien (archivé)'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();

    // Other archived labs are not offered; active ones are.
    expect(find.text('Labo Autre (archivé)'), findsNothing);
    expect(find.text('Labo Actif'), findsWidgets);
  });
}
