// Creating a patient dossier: the app stores no personal data (the server
// generates a pseudonymous reference), so creation is one confirmed action.
// What the person needs back is WHICH reference they just got.

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/patients/data/models/patient_data.dart';
import 'package:steriymed_mobile/features/patients/data/repositories/patient_repository.dart';
import 'package:steriymed_mobile/features/patients/presentation/bloc/patient_list_bloc.dart';
import 'package:steriymed_mobile/features/patients/presentation/screens/patient_search_screen.dart';

import '../helpers/pump_app.dart';

class _Repo extends Mock implements PatientRepository {}

class _Session extends Mock implements SessionStore {}

const _existing = PatientData(id: 'p1', reference: 'PAT-000001');
const _created = PatientData(id: 'p2', reference: 'PAT-000002');

void main() {
  late _Repo repo;

  setUp(() {
    repo = _Repo();
    when(() => repo.search(any(), forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => [_existing]);
    final session = _Session();
    when(() => session.hasPermission(any())).thenReturn(true);
    final di = GetIt.instance;
    if (di.isRegistered<PatientRepository>()) di.unregister<PatientRepository>();
    if (di.isRegistered<SessionStore>()) di.unregister<SessionStore>();
    di
      ..registerSingleton<PatientRepository>(repo)
      ..registerSingleton<SessionStore>(session);
  });

  tearDown(() => GetIt.instance.reset());

  group('bloc', () {
    test('a created dossier is reported, then the list reloads', () async {
      when(() => repo.create()).thenAnswer((_) async => _created);
      final bloc = PatientListBloc(repo);
      bloc.add(const CreatePatient());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.lastCreated, _created);
      verify(() => repo.search('', forceRefresh: true)).called(1);
      await bloc.close();
    });

    test('a refusal reports the error and no dossier', () async {
      when(() => repo.create()).thenThrow(
        const ApiException(code: 'FORBIDDEN', message: 'Action non autorisée.'),
      );
      final bloc = PatientListBloc(repo);
      bloc.add(const CreatePatient());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.lastCreated, isNull);
      expect(bloc.state.error, 'Action non autorisée.');
      await bloc.close();
    });
  });

  group('screen', () {
    Future<void> pump(WidgetTester tester) async {
      await pumpApp(tester, const PatientSearchScreen());
      await tester.pumpAndSettle();
    }

    testWidgets('creating shows the new reference with a way to open it',
        (tester) async {
      when(() => repo.create()).thenAnswer((_) async => _created);
      when(() => repo.search(any(), forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => [_existing, _created]);
      await pump(tester);

      await tester.tap(find.byTooltip('Nouveau dossier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Dossier PAT-000002 créé.'), findsOneWidget);
      expect(find.text('Ouvrir'), findsOneWidget);
      verify(() => repo.create()).called(1);
    });

    testWidgets('cancelling the confirmation creates nothing', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Nouveau dossier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      verifyNever(() => repo.create());
    });

    testWidgets('a role without patients.manage is not offered creation',
        (tester) async {
      final session = GetIt.instance<SessionStore>();
      when(() => session.hasPermission(any())).thenReturn(false);
      await pump(tester);
      expect(find.byTooltip('Nouveau dossier'), findsNothing);
    });
  });
}
