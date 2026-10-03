// The patient picker must show patients as soon as it opens. On a real phone
// it opened blank until something was typed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/features/patients/data/models/patient_data.dart';
import 'package:steriymed_mobile/features/patients/data/repositories/patient_repository.dart';
import 'package:steriymed_mobile/features/patients/presentation/widgets/patient_picker_sheet.dart';

import '../helpers/pump_app.dart';

class _Repo extends Mock implements PatientRepository {}

void main() {
  late _Repo repo;

  setUp(() {
    repo = _Repo();
    when(() => repo.search(any(), forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => const [
              PatientData(id: 'p1', reference: 'PAT-000001'),
              PatientData(id: 'p2', reference: 'PAT-000002'),
            ]);
    if (GetIt.instance.isRegistered<PatientRepository>()) {
      GetIt.instance.unregister<PatientRepository>();
    }
    GetIt.instance.registerSingleton<PatientRepository>(repo);
  });

  tearDown(() => GetIt.instance.reset());

  Future<void> open(WidgetTester tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => PatientPickerSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows patients immediately, without typing anything', (tester) async {
    await open(tester);
    expect(find.text('PAT-000001'), findsOneWidget);
    expect(find.text('PAT-000002'), findsOneWidget);
    verify(() => repo.search('', forceRefresh: any(named: 'forceRefresh'))).called(1);
  });

  testWidgets('choosing a patient returns it', (tester) async {
    PatientData? picked;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async => picked = await PatientPickerSheet.show(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PAT-000002'));
    await tester.pumpAndSettle();
    expect(picked?.reference, 'PAT-000002');
  });
}
