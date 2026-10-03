// The laboratories screen: who they are, how much work each holds (counted by
// the server), their detail, and the form. A failed count must say so, never
// show a zero.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/laboratory_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_summary_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/repositories/prosthetic_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/screens/prosthetic_laboratories_screen.dart';
import 'package:steriymed_mobile/shared/widgets/inputs/app_text_area.dart';

import '../fixtures/prosthetic_case_fixture.dart';
import '../helpers/pump_app.dart';

class _Repo extends Mock implements ProstheticRepository {}

class _Session extends Mock implements SessionStore {}

const _martin = LaboratoryData(
  id: 'lab-1',
  name: 'Labo Martin',
  contactName: 'Claire Martin',
  contactPhone: '+33 1 42 00 00 00',
  contactEmail: 'contact@labo-martin.example.fr',
  address: '12 rue de la Paix, Paris',
  notes: 'Livraison le mardi et le vendredi.',
);
const _sud = LaboratoryData(id: 'lab-2', name: 'Dental Sud');

void main() {
  late _Repo repo;
  late _Session session;

  void stubSummary(String labId, {required int atLab, required int waiting, required int total, int urgent = 0}) {
    when(() => repo.summary(
          laboratoryId: labId,
          scope: any(named: 'scope'),
        )).thenAnswer((i) async {
      final scope = i.namedArguments[#scope] as String?;
      return switch (scope) {
        'at_laboratory' => ProstheticSummaryData(total: atLab),
        'waiting_for_placement' =>
          ProstheticSummaryData(total: waiting, fresh: waiting - urgent, urgent: urgent),
        _ => ProstheticSummaryData(total: total),
      };
    });
  }

  setUp(() {
    repo = _Repo();
    session = _Session();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => repo.listLaboratories(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => [_martin, _sud]);
    stubSummary('lab-1', atLab: 2, waiting: 3, total: 14, urgent: 1);
    stubSummary('lab-2', atLab: 0, waiting: 0, total: 0);
    when(() => repo.list(laboratoryId: any(named: 'laboratoryId'))).thenAnswer(
      (_) async => CursorPage(items: [
        buildProstheticCase(id: 'c1', patientReference: 'PAT-000007', laboratoryId: 'lab-1'),
      ]),
    );
    final di = GetIt.instance;
    for (final reset in [
      () => di.isRegistered<ProstheticRepository>() ? di.unregister<ProstheticRepository>() : null,
      () => di.isRegistered<SessionStore>() ? di.unregister<SessionStore>() : null,
    ]) {
      reset();
    }
    di
      ..registerSingleton<ProstheticRepository>(repo)
      ..registerSingleton<SessionStore>(session);
  });

  tearDown(() => GetIt.instance.reset());

  Future<void> open(WidgetTester tester) async {
    await pumpApp(tester, const ProstheticLaboratoriesScreen());
    await tester.pumpAndSettle();
  }

  testWidgets('each card shows its identity and the server-counted work', (tester) async {
    await open(tester);
    expect(find.text('Labo Martin'), findsOneWidget);
    expect(find.text('Claire Martin'), findsOneWidget);
    expect(find.text('2 chez le laboratoire'), findsOneWidget);
    expect(find.text('3 à poser · 1 en retard'), findsOneWidget);
    // A laboratory with nothing in progress says so, in words.
    expect(find.text('Aucun travail en cours'), findsOneWidget);
    expect(find.byKey(const Key('lab-count')), findsOneWidget);
    expect(find.text('2 laboratoires partenaires'), findsOneWidget);
  });

  testWidgets('a failed count says "indisponible", never a zero', (tester) async {
    when(() => repo.summary(laboratoryId: 'lab-2', scope: any(named: 'scope')))
        .thenThrow(Exception('offline'));
    await open(tester);
    expect(find.byKey(const Key('lab-stats-unavailable')), findsOneWidget);
    expect(find.text('Aucun travail en cours'), findsNothing);
  });

  testWidgets('search narrows the list by name or contact', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, 'sud');
    await tester.pumpAndSettle();
    expect(find.text('Dental Sud'), findsOneWidget);
    expect(find.text('Labo Martin'), findsNothing);
    expect(find.text('1 résultat'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'claire');
    await tester.pumpAndSettle();
    expect(find.text('Labo Martin'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Aucun laboratoire ne correspond.'), findsOneWidget);
  });

  testWidgets('the sheet shows numbers, aging, contact, notes and recent cases', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('lab-lab-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lab-sheet-stats')), findsOneWidget);
    expect(find.textContaining('2 de 0 à 7 j'), findsOneWidget);
    expect(find.textContaining('1 de 15 j et plus'), findsOneWidget);
    expect(find.text('12 rue de la Paix, Paris'), findsWidgets);
    expect(find.text('Livraison le mardi et le vendredi.'), findsOneWidget);
    expect(find.byKey(const Key('lab-recent-cases')), findsOneWidget);
    expect(find.text('PAT-000007'), findsOneWidget);
  });

  testWidgets('a laboratory with no work says so in its sheet', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('lab-lab-2')));
    await tester.pumpAndSettle();
    expect(find.text('Aucun contact enregistré. Ajoutez un téléphone ou un e-mail pour pouvoir appeler ou écrire en un geste.'), findsOneWidget);
  });

  testWidgets('edit and archive are offered only to someone who can manage', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('lab-lab-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lab-edit')), findsOneWidget);
    expect(find.byKey(const Key('lab-archive')), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    when(() => session.hasPermission('prosthetic_cases.manage')).thenReturn(false);
    await tester.tap(find.byKey(const Key('lab-lab-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lab-edit')), findsNothing);
    expect(find.byKey(const Key('lab-archive')), findsNothing);
  });

  testWidgets('the form sends the address and the notes with the rest', (tester) async {
    Map<String, dynamic>? sent;
    when(() => repo.createLaboratory(any())).thenAnswer((i) async {
      sent = Map<String, dynamic>.from(i.positionalArguments.first as Map);
      return const LaboratoryData(id: 'new', name: 'Nouveau');
    });
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester);
    await tester.tap(find.byTooltip('Nouveau laboratoire'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Nouveau Labo');
    await tester.enterText(fields.at(1), 'Paul Durand');
    await tester.enterText(fields.at(2), '0102030405');
    await tester.enterText(fields.at(3), 'paul@labo.example.fr');
    final areas = find.descendant(
        of: find.byType(AppTextArea), matching: find.byType(TextField));
    await tester.enterText(areas.at(0), '5 avenue Victor Hugo');
    await tester.enterText(areas.at(1), 'Fermé le lundi');
    await tester.tap(find.text('Ajouter le laboratoire'));
    await tester.pumpAndSettle();

    expect(sent, isNotNull);
    expect(sent!['name'], 'Nouveau Labo');
    expect(sent!['contact_email'], 'paul@labo.example.fr');
    expect(sent!['address'], '5 avenue Victor Hugo');
    expect(sent!['notes'], 'Fermé le lundi');
  });

  testWidgets('a bad e-mail is refused before anything is sent', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Nouveau laboratoire'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'X');
    await tester.enterText(fields.at(3), 'pas-un-email');
    await tester.tap(find.text('Ajouter le laboratoire'));
    await tester.pumpAndSettle();
    expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
    verifyNever(() => repo.createLaboratory(any()));
  });
}
