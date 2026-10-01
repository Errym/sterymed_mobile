// RBAC completion pass — role-specific mutating-action visibility.
//
// Role → permission sets below are copied verbatim from steriqore's real
// seed source, not guessed: `App\Domain\Identity\Actions\
// SeedTenantRolesAction::PERMISSIONS_BY_ROLE` (`owner`/`admin` derive from
// the shared `PERMISSIONS` + `OWNER_ONLY_PERMISSIONS` constants there),
// verified 2026-09-27 by reading that file directly. `docs/ROLE_MATRIX.md`
// carries the same table for reference.
//
// Covers 3 required scenarios:
//   - a practitioner (has prosthetic_cases.manage, NOT
//     prosthetic_payments.manage) does not see a payment edit button.
//   - a stock_manager (has cycles.manage, NOT cycles.release) does not see
//     the cycle release action.
//   - a viewer (no *.manage permission at all) sees no mutating button on
//     a representative sample of screens — not exhaustively every
//     mutating control in the entire app, which is out of proportion for
//     one test file; see the individual assertions for exactly what's
//     checked.
//
// Real discrepancy found while writing this, not silently resolved:
// bottom_nav_bar_test below shows a *viewer* currently sees all 6 tabs,
// including Scanner — `RoleGuard` gates Routes.scanner on `labels.view`,
// which the real backend grants to every role including viewer. If the
// intent is "viewer should not see Scanner," that needs a deliberate
// backend/product decision about what permission should gate it instead
// (viewer legitimately has labels.view, so gating on that alone doesn't
// exclude viewer) — not something to silently change here.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import '../mocks/fake_cycle_notes_cache.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/router/guards/role_guard.dart';
import 'package:steriymed_mobile/core/router/routes.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/cycles/data/models/cycle_data.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/cycle_repository.dart';
import 'package:steriymed_mobile/features/cycles/presentation/screens/cycle_detail_screen.dart';
import 'package:steriymed_mobile/features/dlu/data/repositories/dlu_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_case_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/repositories/prosthetic_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/screens/prosthetic_case_detail_screen.dart';
import 'package:steriymed_mobile/features/shell/presentation/widgets/bottom_nav_bar.dart';

import '../helpers/pump_app.dart';

// ─────────────────────────────────────────────────────────────────────────
// Real backend role → permission grants (SeedTenantRolesAction.php)
// ─────────────────────────────────────────────────────────────────────────

const _basePermissions = <String>[
  'invitations.create', 'invitations.revoke', 'memberships.disable',
  'sites.view', 'sites.manage', 'audit.view',
  'products.view', 'products.manage',
  'suppliers.view', 'suppliers.manage',
  'purchasing.view', 'purchasing.manage',
  'inventory.view', 'inventory.manage',
  'alerts.view', 'alerts.manage',
  'devices.view', 'devices.manage',
  'cycles.view', 'cycles.manage', 'cycles.release',
  'labels.view', 'labels.manage',
  'patients.view', 'patients.manage',
  'usages.view', 'usages.manage',
  'exports.manage',
  'non_conformities.view', 'non_conformities.manage',
  'data_exports.manage', 'practice_settings.manage',
  'prosthetic_cases.view', 'prosthetic_cases.manage',
  'prosthetic_payments.manage',
];

const _rolePermissions = <String, List<String>>{
  'owner': [..._basePermissions, 'evidence_settings.manage'],
  'admin': _basePermissions,
  'stock_manager': [
    'sites.view', 'products.view', 'products.manage',
    'suppliers.view', 'suppliers.manage', 'purchasing.view',
    'purchasing.manage', 'inventory.view', 'inventory.manage',
    'alerts.view', 'alerts.manage', 'devices.view', 'devices.manage',
    'cycles.view', 'cycles.manage', 'labels.view', 'labels.manage',
    'patients.view', 'usages.view', 'non_conformities.view',
    'prosthetic_cases.view',
  ],
  'releaser': [
    'sites.view', 'products.view', 'suppliers.view', 'purchasing.view',
    'inventory.view', 'alerts.view', 'devices.view', 'cycles.view',
    'cycles.release', 'labels.view', 'patients.view', 'usages.view',
    'non_conformities.view', 'non_conformities.manage',
    'prosthetic_cases.view',
  ],
  'practitioner': [
    'sites.view', 'products.view', 'suppliers.view', 'purchasing.view',
    'inventory.view', 'alerts.view', 'devices.view', 'cycles.view',
    'labels.view', 'patients.view', 'patients.manage', 'usages.view',
    'usages.manage', 'non_conformities.view', 'prosthetic_cases.view',
    'prosthetic_cases.manage',
  ],
  'viewer': [
    'sites.view', 'products.view', 'suppliers.view', 'purchasing.view',
    'inventory.view', 'alerts.view', 'devices.view', 'cycles.view',
    'labels.view', 'patients.view', 'usages.view',
    'non_conformities.view', 'prosthetic_cases.view',
  ],
};

class MockSessionStore extends Mock implements SessionStore {}

class MockCycleRepository extends Mock implements CycleRepository {}

class MockDluRepository extends Mock implements DluRepository {}

class MockProstheticRepository extends Mock implements ProstheticRepository {}

CycleData _buildCycle({String status = 'created'}) => CycleData(
      id: 'cycle-1',
      number: 'CT-042',
      status: status,
      deviceId: 'device-1',
      deviceName: 'Melag Vacuklav',
      createdAt: DateTime(2026, 9, 20, 8, 0),
    );

ProstheticCaseData _buildProstheticCase() => ProstheticCaseData(
      id: 'case-1',
      patientId: 'p1',
      patientReference: 'PAT-000001',
      practitionerId: 'prat-1',
      practitionerName: 'Dr Test',
      status: ProstheticCaseStatus.sentToLaboratory,
      impressionType: ProstheticImpressionType.digital,
      workType: ProstheticWorkType.crown,
      impressionDate: DateTime(2026, 9, 1),
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  group('BottomNavBar — tabs visible per role', () {
    late MockSessionStore session;

    setUp(() {
      session = MockSessionStore();
      if (GetIt.instance.isRegistered<SessionStore>()) {
        GetIt.instance.unregister<SessionStore>();
      }
      GetIt.instance.registerSingleton<SessionStore>(session);
    });

    tearDown(() => GetIt.instance.unregister<SessionStore>());

    for (final role in _rolePermissions.keys) {
      testWidgets('$role sees exactly the tabs RoleGuard allows',
          (tester) async {
        final perms = _rolePermissions[role]!.toSet();
        when(() => session.hasPermission(any()))
            .thenAnswer((i) => perms.contains(i.positionalArguments.first));

        await pumpApp(
          tester,
          const Scaffold(body: BottomNavBar(currentLocation: Routes.dashboard)),
        );
        await tester.pump();

        const allTabs = {
          'Accueil': Routes.dashboard,
          'Scanner': Routes.scanner,
          'Cycles': Routes.cycles,
          'Stock': Routes.stock,
          'Alertes': Routes.alerts,
          'Plus': Routes.settings,
        };
        for (final entry in allTabs.entries) {
          final expected = RoleGuard.isAllowed(
            route: entry.value,
            hasPermission: (p) => perms.contains(p),
          );
          expect(
            find.text(entry.key),
            expected ? findsOneWidget : findsNothing,
            reason: '$role, tab "${entry.key}"',
          );
        }
      });
    }

    testWidgets(
      'DISCREPANCY: viewer currently sees Scanner too — RoleGuard gates '
      'it on labels.view, which viewer legitimately has. Flagging, not '
      'silently changing the gate.',
      (tester) async {
        final perms = _rolePermissions['viewer']!.toSet();
        when(() => session.hasPermission(any()))
            .thenAnswer((i) => perms.contains(i.positionalArguments.first));

        await pumpApp(
          tester,
          const Scaffold(body: BottomNavBar(currentLocation: Routes.dashboard)),
        );
        await tester.pump();

        expect(find.text('Scanner'), findsOneWidget);
      },
    );
  });

  group('practitioner does not see a payment edit button', () {
    late MockSessionStore session;
    late MockProstheticRepository repo;

    setUp(() {
      session = MockSessionStore();
      repo = MockProstheticRepository();
      final perms = _rolePermissions['practitioner']!.toSet();
      when(() => session.hasPermission(any()))
          .thenAnswer((i) => perms.contains(i.positionalArguments.first));
      when(() => repo.show(any()))
          .thenAnswer((_) async => _buildProstheticCase());
      when(() => repo.statusHistory(any())).thenAnswer((_) async => []);
      when(() => repo.listAttachments(any())).thenAnswer((_) async => []);

      if (GetIt.instance.isRegistered<SessionStore>()) {
        GetIt.instance.unregister<SessionStore>();
      }
      if (GetIt.instance.isRegistered<ProstheticRepository>()) {
        GetIt.instance.unregister<ProstheticRepository>();
      }
      GetIt.instance.registerSingleton<SessionStore>(session);
      GetIt.instance.registerSingleton<ProstheticRepository>(repo);
    });

    tearDown(() {
      GetIt.instance.unregister<SessionStore>();
      GetIt.instance.unregister<ProstheticRepository>();
    });

    testWidgets(
      'practitioner has prosthetic_cases.manage (sees Quick Edit) but not '
      'prosthetic_payments.manage (no "Enregistrer le paiement" button, '
      'read-only payment card instead)',
      (tester) async {
        await pumpApp(
          tester,
          const ProstheticCaseDetailScreen(caseId: 'case-1'),
        );
        await tester.pumpAndSettle();

        // Sanity: practitioner DOES have clinical-manage, so Quick Edit
        // is visible — proves the absence below is the payment gate
        // specifically, not every permission being denied.
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

        expect(find.text('Enregistrer le paiement'), findsNothing);
        expect(find.byType(SwitchListTile), findsNothing);
        expect(find.textContaining('Paiement'), findsOneWidget);
      },
    );
  });

  group('stock_manager does not see the cycle release action', () {
    late MockSessionStore session;
    late MockCycleRepository cycleRepo;
    late MockDluRepository dluRepo;
    late Directory tempDir;

    setUpAll(() async {
      // CycleDetailScreen's notes section opens a real Hive box directly —
      // see cycle_detail_screen_test.dart's header comment for why this
      // must be pre-opened outside the widget-test zone.
      tempDir = await Directory.systemTemp.createTemp('rbac_matrix_test');
      Hive.init(tempDir.path);
      await Hive.openBox('steriymed.cycle_notes');
    });

    tearDownAll(() async {
      await Hive.box('steriymed.cycle_notes').close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    setUp(() {
      session = MockSessionStore();
      cycleRepo = MockCycleRepository();
      dluRepo = MockDluRepository();
      final perms = _rolePermissions['stock_manager']!.toSet();
      when(() => session.hasPermission(any()))
          .thenAnswer((i) => perms.contains(i.positionalArguments.first));
      when(() => cycleRepo.show(any()))
          .thenAnswer((_) async => _buildCycle(status: 'awaiting_release'));
      when(() => cycleRepo.listItems(any())).thenAnswer((_) async => []);
      when(() => cycleRepo.listControlTests(any()))
          .thenAnswer((_) async => []);
      when(() => cycleRepo.listAttachments(any()))
          .thenAnswer((_) async => []);
      when(() => cycleRepo.countLabels(any())).thenAnswer((_) async => 0);

      if (GetIt.instance.isRegistered<SessionStore>()) {
        GetIt.instance.unregister<SessionStore>();
      }
      if (GetIt.instance.isRegistered<CycleRepository>()) {
        GetIt.instance.unregister<CycleRepository>();
      }
      if (GetIt.instance.isRegistered<DluRepository>()) {
        GetIt.instance.unregister<DluRepository>();
      }
      GetIt.instance.registerSingleton<SessionStore>(session);
      GetIt.instance.registerSingleton<CycleRepository>(cycleRepo);
      GetIt.instance.registerSingleton<DluRepository>(dluRepo);
      registerFakeCycleNotesCache();
    });

    tearDown(() {
      GetIt.instance.unregister<SessionStore>();
      GetIt.instance.unregister<CycleRepository>();
      GetIt.instance.unregister<DluRepository>();
    });

    testWidgets(
      'stock_manager has cycles.manage (can start/complete cycles) but '
      'not cycles.release — sees the read-only banner instead of '
      '"Prendre la décision de libération" on an awaiting_release cycle',
      (tester) async {
        await pumpApp(
          tester,
          RepositoryProvider<CycleRepository>.value(
            value: cycleRepo,
            child: const CycleDetailScreen(cycleId: 'cycle-1'),
          ),
        );
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(find.text('Prendre la décision de libération'), findsNothing);
        expect(find.textContaining('lecture seule'), findsOneWidget);
      },
    );
  });

  group('viewer sees no mutating button (representative screens)', () {
    late MockSessionStore session;
    late MockCycleRepository cycleRepo;
    late MockDluRepository dluRepo;
    late MockProstheticRepository prostheticRepo;
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('rbac_matrix_viewer');
      Hive.init(tempDir.path);
      await Hive.openBox('steriymed.cycle_notes');
    });

    tearDownAll(() async {
      await Hive.box('steriymed.cycle_notes').close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    setUp(() {
      session = MockSessionStore();
      cycleRepo = MockCycleRepository();
      dluRepo = MockDluRepository();
      prostheticRepo = MockProstheticRepository();
      final perms = _rolePermissions['viewer']!.toSet();
      when(() => session.hasPermission(any()))
          .thenAnswer((i) => perms.contains(i.positionalArguments.first));

      when(() => cycleRepo.show(any()))
          .thenAnswer((_) async => _buildCycle(status: 'created'));
      when(() => cycleRepo.listItems(any())).thenAnswer((_) async => []);
      when(() => cycleRepo.listControlTests(any()))
          .thenAnswer((_) async => []);
      when(() => cycleRepo.listAttachments(any()))
          .thenAnswer((_) async => []);
      when(() => cycleRepo.countLabels(any())).thenAnswer((_) async => 0);

      when(() => prostheticRepo.show(any()))
          .thenAnswer((_) async => _buildProstheticCase());
      when(() => prostheticRepo.statusHistory(any()))
          .thenAnswer((_) async => []);
      when(() => prostheticRepo.listAttachments(any()))
          .thenAnswer((_) async => []);

      if (GetIt.instance.isRegistered<SessionStore>()) {
        GetIt.instance.unregister<SessionStore>();
      }
      if (GetIt.instance.isRegistered<CycleRepository>()) {
        GetIt.instance.unregister<CycleRepository>();
      }
      if (GetIt.instance.isRegistered<DluRepository>()) {
        GetIt.instance.unregister<DluRepository>();
      }
      if (GetIt.instance.isRegistered<ProstheticRepository>()) {
        GetIt.instance.unregister<ProstheticRepository>();
      }
      GetIt.instance.registerSingleton<SessionStore>(session);
      GetIt.instance.registerSingleton<CycleRepository>(cycleRepo);
      GetIt.instance.registerSingleton<DluRepository>(dluRepo);
      registerFakeCycleNotesCache();
      GetIt.instance.registerSingleton<ProstheticRepository>(prostheticRepo);
    });

    tearDown(() {
      GetIt.instance.unregister<SessionStore>();
      GetIt.instance.unregister<CycleRepository>();
      GetIt.instance.unregister<DluRepository>();
      GetIt.instance.unregister<ProstheticRepository>();
    });

    testWidgets('cycle detail: no start button, read-only banner instead',
        (tester) async {
      await pumpApp(
        tester,
        RepositoryProvider<CycleRepository>.value(
          value: cycleRepo,
          child: const CycleDetailScreen(cycleId: 'cycle-1'),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Démarrer le cycle'), findsNothing);
      expect(find.textContaining('lecture seule'), findsOneWidget);
    });

    testWidgets(
      'prosthetic case detail: no Quick Edit icon, no status-change '
      'buttons, payment section read-only',
      (tester) async {
        await pumpApp(
          tester,
          const ProstheticCaseDetailScreen(caseId: 'case-1'),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.text('Changer le statut'), findsNothing);
        expect(find.byType(SwitchListTile), findsNothing);
        expect(find.text('Enregistrer le paiement'), findsNothing);
      },
    );
  });
}
