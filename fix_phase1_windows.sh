#!/usr/bin/env bash
# =============================================================================
# SteryMed Mobile — Phase 1 Fix (Windows + Git Bash friendly)
# =============================================================================
# Fixes the 5 test compilation errors from the Phase 1 run.
# No Python. No Perl. Only bash + coreutils.
#
# Usage:
#   chmod +x fix_phase1_windows.sh
#   ./fix_phase1_windows.sh
# =============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_step() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}▶ $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}
log_ok()   { echo -e "${GREEN}✓ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
log_err()  { echo -e "${RED}✗ $1${NC}"; }
fatal()    { log_err "$1"; exit 1; }

# ─────────────────────────────────────────────────────────────────────────────
# Step 1 — Confirm we're on the phase-1 branch
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 1 / 6 — Confirm branch"

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "Current branch: $CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" != "phase-1-testing" ]; then
  log_warn "Not on phase-1-testing. Switching..."
  if git show-ref --verify --quiet "refs/heads/phase-1-testing"; then
    git checkout phase-1-testing
  else
    git checkout -b phase-1-testing
  fi
fi
log_ok "On phase-1-testing"

# ─────────────────────────────────────────────────────────────────────────────
# Step 2 — Ensure folder structure exists
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 2 / 6 — Ensure folder structure"

mkdir -p test/unit/core
mkdir -p test/unit/storage
mkdir -p test/bloc
mkdir -p test/widget
mkdir -p test/mocks
mkdir -p test/fixtures
mkdir -p test/helpers

log_ok "Folders ready"

# ─────────────────────────────────────────────────────────────────────────────
# Step 3 — Write pump_app.dart (the missing helper)
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 3 / 6 — Write test/helpers/pump_app.dart"

cat > test/helpers/pump_app.dart <<'DARTEOF'
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a widget inside a standard MaterialApp with French localization.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('fr'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}
DARTEOF
log_ok "pump_app.dart written"

# ─────────────────────────────────────────────────────────────────────────────
# Step 4 — Write alert_fixture.dart with correct import
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 4 / 6 — Write test/fixtures/alert_fixture.dart"

cat > test/fixtures/alert_fixture.dart <<'DARTEOF'
import 'package:steriymed_mobile/features/alerts/data/models/alert_data.dart';

AlertData buildAlert({
  String id = 'alert-1',
  AlertSeverity severity = AlertSeverity.critical,
  String type = 'low_stock',
}) {
  return AlertData(
    id: id,
    type: type,
    severity: severity,
    message: 'Stock faible pour Gants nitrile',
    createdAt: DateTime(2026, 9, 18, 10, 0),
    resolved: false,
  );
}
DARTEOF
log_ok "alert_fixture.dart written"

# ─────────────────────────────────────────────────────────────────────────────
# Step 5 — Rewrite the 5 failing test files
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 5 / 6 — Rewrite failing test files"

# ── 5a. alert_list_bloc_test.dart ──
cat > test/bloc/alert_list_bloc_test.dart <<'DARTEOF'
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/alerts/data/models/alert_data.dart';
import 'package:steriymed_mobile/features/alerts/data/repositories/alert_repository.dart';
import 'package:steriymed_mobile/features/alerts/presentation/bloc/alert_list_bloc.dart';

import '../fixtures/alert_fixture.dart';

class MockAlertRepository extends Mock implements AlertRepository {}

void main() {
  late MockAlertRepository repo;

  setUp(() {
    repo = MockAlertRepository();
  });

  group('AlertListBloc', () {
    blocTest<AlertListBloc, AlertListState>(
      'loads alerts',
      build: () => AlertListBloc(repo),
      setUp: () {
        when(() => repo.getActiveAlerts(
              forceRefresh: any(named: 'forceRefresh'),
            )).thenAnswer((_) async => [buildAlert()]);
      },
      act: (b) => b.add(const LoadAlerts()),
      expect: () => [
        isA<AlertListState>()
            .having((s) => s.status, 'status', AlertListStatus.loading),
        isA<AlertListState>()
            .having((s) => s.status, 'status', AlertListStatus.success)
            .having((s) => s.alerts.length, 'alerts', 1),
      ],
    );

    blocTest<AlertListBloc, AlertListState>(
      'emits failure on error',
      build: () => AlertListBloc(repo),
      setUp: () {
        when(() => repo.getActiveAlerts(
              forceRefresh: any(named: 'forceRefresh'),
            )).thenThrow(const ApiException(
          code: 'server_error',
          message: 'Erreur serveur.',
        ));
      },
      act: (b) => b.add(const LoadAlerts()),
      expect: () => [
        isA<AlertListState>()
            .having((s) => s.status, 'status', AlertListStatus.loading),
        isA<AlertListState>()
            .having((s) => s.status, 'status', AlertListStatus.failure),
      ],
    );

    test('severity grouping', () {
      final state = AlertListState(
        alerts: [
          buildAlert(id: 'a1', severity: AlertSeverity.critical),
          buildAlert(id: 'a2', severity: AlertSeverity.warning),
          buildAlert(id: 'a3', severity: AlertSeverity.warning),
          buildAlert(id: 'a4', severity: AlertSeverity.info),
        ],
      );
      expect(state.criticalAlerts.length, 1);
      expect(state.warningAlerts.length, 2);
      expect(state.infoAlerts.length, 1);
    });
  });
}
DARTEOF
log_ok "alert_list_bloc_test.dart rewritten"

# ── 5b. scanner_bloc_test.dart (no blocTest expectLater) ──
cat > test/bloc/scanner_bloc_test.dart <<'DARTEOF'
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/labels/data/models/label_data.dart';
import 'package:steriymed_mobile/features/labels/data/models/label_scan_result.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_repository.dart';
import 'package:steriymed_mobile/features/scanner/presentation/bloc/scanner_bloc.dart';

class MockLabelRepository extends Mock implements LabelRepository {}

void main() {
  late MockLabelRepository repo;

  setUp(() {
    repo = MockLabelRepository();
  });

  group('ScannerBloc', () {
    test('valid scan resolves and produces a result', () async {
      when(() => repo.getByCode(any())).thenAnswer((_) async =>
          const LabelScanResult(
            code: 'LABEL-1',
            status: LabelScanStatus.valid,
            label: LabelData(id: 'l1', code: 'LABEL-1', status: 'valid'),
          ));

      final bloc = ScannerBloc(repo);
      bloc.add(const ScanDetected('LABEL-1'));

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(bloc.state.status, ScannerStatus.resolved);
      expect(bloc.state.result?.status, LabelScanStatus.valid);
      await bloc.close();
    });

    test('blocked label resolves with blocked status', () async {
      when(() => repo.getByCode(any())).thenAnswer((_) async =>
          const LabelScanResult(
            code: 'LABEL-2',
            status: LabelScanStatus.expired,
            reason: 'Expiré',
          ));

      final bloc = ScannerBloc(repo);
      bloc.add(const ScanDetected('LABEL-2'));

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(bloc.state.status, ScannerStatus.resolved);
      expect(bloc.state.result?.status, LabelScanStatus.expired);
      expect(bloc.state.result?.isBlocked, isTrue);
      await bloc.close();
    });

    test('network error produces error state', () async {
      when(() => repo.getByCode(any()))
          .thenThrow(const ApiException(
        code: 'network_error',
        message: 'Connexion impossible.',
      ));

      final bloc = ScannerBloc(repo);
      bloc.add(const ScanDetected('LABEL-3'));

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(bloc.state.status, ScannerStatus.error);
      expect(bloc.state.error, isNotNull);
      await bloc.close();
    });

    test('torch toggles', () async {
      final bloc = ScannerBloc(repo);
      expect(bloc.state.torchOn, false);
      bloc.add(const TorchToggled());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.torchOn, true);
      bloc.add(const TorchToggled());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.torchOn, false);
      await bloc.close();
    });

    test('reset returns to initial state', () async {
      final bloc = ScannerBloc(repo);
      bloc.add(const ScannerReset());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.status, ScannerStatus.initial);
      await bloc.close();
    });
  });
}
DARTEOF
log_ok "scanner_bloc_test.dart rewritten"

# ── 5c. alert_list_screen_test.dart ──
cat > test/widget/alert_list_screen_test.dart <<'DARTEOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/features/alerts/data/models/alert_data.dart';
import 'package:steriymed_mobile/features/alerts/data/repositories/alert_repository.dart';
import 'package:steriymed_mobile/features/alerts/presentation/bloc/alert_list_bloc.dart';
import 'package:steriymed_mobile/features/alerts/presentation/screens/alert_list_screen.dart';

import '../fixtures/alert_fixture.dart';
import '../helpers/pump_app.dart';

class MockAlertRepository extends Mock implements AlertRepository {}

void main() {
  late MockAlertRepository repo;

  setUp(() {
    repo = MockAlertRepository();
  });

  testWidgets('renders severity groups', (tester) async {
    when(() => repo.getActiveAlerts(
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => [
              buildAlert(id: 'a1', severity: AlertSeverity.critical),
              buildAlert(id: 'a2', severity: AlertSeverity.warning),
              buildAlert(id: 'a3', severity: AlertSeverity.info),
            ]);

    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => AlertListBloc(repo)..add(const LoadAlerts()),
        child: const AlertListScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Critique'), findsOneWidget);
    expect(find.text('Avertissement'), findsOneWidget);
    expect(find.text('Information'), findsOneWidget);
  });

  testWidgets('shows empty view when no alerts', (tester) async {
    when(() => repo.getActiveAlerts(
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => []);

    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => AlertListBloc(repo)..add(const LoadAlerts()),
        child: const AlertListScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aucune alerte active'), findsOneWidget);
  });
}
DARTEOF
log_ok "alert_list_screen_test.dart rewritten"

# ── 5d. user_fixture.dart (const fix) ──
cat > test/fixtures/user_fixture.dart <<'DARTEOF'
import 'package:steriymed_mobile/features/auth/data/models/login_response.dart';
import 'package:steriymed_mobile/features/auth/data/models/tenant_data.dart';
import 'package:steriymed_mobile/features/auth/data/models/user_data.dart';

const testUser = UserData(
  id: 'user-1',
  name: 'Dr Test',
  email: 'test@test.com',
  role: 'owner',
);

const testTenant = TenantData(
  id: 'tenant-1',
  name: 'My Practice',
  slug: 'my-practice',
);

final testLoginResponse = LoginResponse(
  token: 'test-token',
  tokenType: 'Bearer',
  user: testUser,
  tenant: testTenant,
);
DARTEOF
log_ok "user_fixture.dart rewritten"

# ── 5e. login_screen_test.dart (remove unused import) ──
cat > test/widget/login_screen_test.dart <<'DARTEOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:steriymed_mobile/features/auth/presentation/screens/login_screen.dart';

import '../helpers/pump_app.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;

  setUp(() {
    repo = MockAuthRepository();
    registerFallbackValue(Uri());
  });

  testWidgets('renders all fields', (tester) async {
    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => AuthBloc(repo),
        child: const LoginScreen(),
      ),
    );
    expect(find.text('Bienvenue'), findsOneWidget);
    expect(find.text('Identifiant du cabinet'), findsOneWidget);
    expect(find.text('Adresse e-mail'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('shows validation errors on empty submit', (tester) async {
    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => AuthBloc(repo),
        child: const LoginScreen(),
      ),
    );
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.textContaining('obligatoire'), findsWidgets);
  });

  testWidgets('shows email error for invalid email', (tester) async {
    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => AuthBloc(repo),
        child: const LoginScreen(),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'not-an-email');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
  });

  testWidgets('fires AuthLoginSubmitted on valid input', (tester) async {
    when(() => repo.login(
          tenantSlug: any(named: 'tenantSlug'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(const ApiException(
      code: 'unauthenticated',
      message: 'Bad credentials',
    ));

    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => AuthBloc(repo),
        child: const LoginScreen(),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'test');
    await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    verify(() => repo.login(
          tenantSlug: 'test',
          email: 'a@b.com',
          password: 'password123',
        )).called(1);
  });
}
DARTEOF
log_ok "login_screen_test.dart rewritten"

# ─────────────────────────────────────────────────────────────────────────────
# Step 6 — Verify
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 6 / 6 — Verify"

echo ""
echo "Files present:"
for f in \
  test/helpers/pump_app.dart \
  test/fixtures/alert_fixture.dart \
  test/fixtures/user_fixture.dart \
  test/bloc/alert_list_bloc_test.dart \
  test/bloc/scanner_bloc_test.dart \
  test/widget/alert_list_screen_test.dart \
  test/widget/login_screen_test.dart
do
  if [ -f "$f" ]; then
    log_ok "$f ($(wc -l < "$f" | tr -d ' ') lines)"
  else
    log_err "$f MISSING"
  fi
done

echo ""
echo "▶ flutter analyze"
if flutter analyze; then
  log_ok "Analyze clean"
else
  log_warn "Analyze has issues (see above)"
fi

echo ""
echo "▶ flutter test"
if flutter test; then
  log_ok "All tests pass"
else
  log_warn "Some tests still failing (see above)"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Fix applied.${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo "  1. If flutter analyze is clean and flutter test passes:"
echo "       git add -A"
echo "       git commit -m 'test(p1): fix test compilation errors'"
echo "       git push --set-upstream origin phase-1-testing"
echo "       git push origin v0.1.1-phase1"
echo ""
echo "  2. If tests still fail, paste the output here."
echo ""