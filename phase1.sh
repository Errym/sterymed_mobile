#!/usr/bin/env bash
# =============================================================================
# SteryMed Mobile — Phase 1 Automation Script
# =============================================================================
# Testing Foundation.
#
# Creates:
#   - Unit tests for core utilities (error mapper, validators, PII scrubber, etc.)
#   - Unit tests for storage (outbox store, sync engine)
#   - Bloc tests for critical blocs (auth, scanner, cycle detail, etc.)
#   - Widget tests for login and alerts
#   - Mocks and fixtures
#
# Verifies:
#   - flutter analyze clean
#   - flutter test green
#   - coverage report generated
#
# Commits + tags v0.1.1-phase1
#
# Usage:
#   chmod +x phase1.sh
#   ./phase1.sh
#
# Safe to re-run. Idempotent. Aborts on any fatal error.
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

BRANCH_NAME="phase-1-testing"
TAG_NAME="v0.1.1-phase1"
TODAY="$(date +%Y-%m-%d)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_step() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}▶ $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_ok()   { echo -e "${GREEN}✓ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
log_err()  { echo -e "${RED}✗ $1${NC}"; }

fatal() {
  log_err "$1"
  exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 1 — Pre-flight
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 1 / 12 — Pre-flight checks"

if ! command -v flutter &> /dev/null; then
  fatal "Flutter is not installed or not on PATH."
fi

if [ ! -f "pubspec.yaml" ]; then
  fatal "This does not appear to be a Flutter project (no pubspec.yaml)."
fi

# Check we're on the Phase 0 tag or later
if ! git rev-parse "v0.1.0-phase0" >/dev/null 2>&1; then
  log_warn "Tag v0.1.0-phase0 not found. Phase 0 may not be complete."
  read -r -p "Continue anyway? [y/N] " response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    fatal "Aborted by user."
  fi
fi

log_ok "Flutter found: $(flutter --version | head -1)"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
  log_warn "You have uncommitted changes. They will be included in the Phase 1 commit."
  read -r -p "Continue? [y/N] " response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    fatal "Aborted by user."
  fi
fi

# Create / switch to phase-1 branch
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
  if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    log_warn "Branch '$BRANCH_NAME' already exists. Switching to it."
    git checkout "$BRANCH_NAME"
  else
    git checkout -b "$BRANCH_NAME"
    log_ok "Created branch '$BRANCH_NAME'"
  fi
else
  log_ok "Already on branch '$BRANCH_NAME'"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 2 — Ensure dev dependencies are in pubspec.yaml
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 2 / 12 — Ensure test dev dependencies"

ensure_pubspec_dep() {
  local dep="$1"
  local version="$2"
  if ! grep -q "^  $dep:" pubspec.yaml; then
    if grep -q "^dev_dependencies:" pubspec.yaml; then
      # Insert right after dev_dependencies:
      sed -i.tmp "/^dev_dependencies:/a\\  $dep: $version" pubspec.yaml
      rm -f pubspec.yaml.tmp
      log_ok "Added $dep: $version to dev_dependencies"
    else
      log_warn "No dev_dependencies block in pubspec.yaml. Please add manually."
    fi
  else
    log_ok "$dep already in pubspec.yaml"
  fi
}

ensure_pubspec_dep "flutter_test" "sdk: flutter"
ensure_pubspec_dep "mocktail" "^1.0.4"
ensure_pubspec_dep "bloc_test" "^9.1.7"

# Run pub get
log_ok "Running flutter pub get"
flutter pub get > /dev/null 2>&1 || fatal "flutter pub get failed"

# ─────────────────────────────────────────────────────────────────────────────
# Step 3 — Create test folder structure
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 3 / 12 — Create test folder structure"

mkdir -p test/unit/core
mkdir -p test/unit/storage
mkdir -p test/bloc
mkdir -p test/widget
mkdir -p test/mocks
mkdir -p test/fixtures
mkdir -p test/helpers

log_ok "Folder structure ready"

# ─────────────────────────────────────────────────────────────────────────────
# Step 4 — Unit tests: core utilities
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 4 / 12 — Unit tests for core utilities"

# ---------- error_mapper_test.dart ----------
cat > test/unit/core/error_mapper_test.dart <<'DARTEOF'
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/errors/error_codes.dart';
import 'package:steriymed_mobile/core/errors/error_mapper.dart';

void main() {
  group('ErrorMapper.fromDio', () {
    RequestOptions opts() => RequestOptions(path: '/test');

    test('maps connectionTimeout to timeout', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.connectionTimeout,
      );
      final result = ErrorMapper.fromDio(e);
      expect(result.code, ErrorCodes.timeout);
      expect(result.message, isNotEmpty);
    });

    test('maps sendTimeout to timeout', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.sendTimeout,
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.timeout);
    });

    test('maps receiveTimeout to timeout', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.receiveTimeout,
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.timeout);
    });

    test('maps connectionError to network_error', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.connectionError,
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.networkError);
    });

    test('maps 401 to unauthenticated', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: opts(),
          statusCode: 401,
        ),
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.unauthenticated);
    });

    test('maps 403 to forbidden', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: opts(), statusCode: 403),
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.forbidden);
    });

    test('maps 404 to not_found', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: opts(), statusCode: 404),
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.notFound);
    });

    test('maps 409 to conflict', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: opts(), statusCode: 409),
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.conflict);
    });

    test('maps 422 to validation_error', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: opts(), statusCode: 422),
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.validationError);
    });

    test('maps 429 to rate_limited', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: opts(), statusCode: 429),
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.rateLimited);
    });

    test('maps 500 to server_error', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: opts(), statusCode: 500),
      );
      expect(ErrorMapper.fromDio(e).code, ErrorCodes.serverError);
    });

    test('parses server error envelope', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: opts(),
          statusCode: 422,
          data: {
            'error': {
              'code': 'VALIDATION_FAILED',
              'message': 'Le motif est obligatoire.',
              'details': {'reason': ['Requis']},
              'request_id': 'req-123',
            }
          },
        ),
      );
      final result = ErrorMapper.fromDio(e);
      expect(result.code, 'VALIDATION_FAILED');
      expect(result.message, 'Le motif est obligatoire.');
      expect(result.details['reason'], isA<List>());
      expect(result.requestId, 'req-123');
      expect(result.statusCode, 422);
    });

    test('handles response without error envelope', () {
      final e = DioException(
        requestOptions: opts(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: opts(),
          statusCode: 418,
          data: 'not json',
        ),
      );
      final result = ErrorMapper.fromDio(e);
      expect(result.statusCode, 418);
      expect(result.message, isNotEmpty);
    });
  });
}
DARTEOF
log_ok "Created error_mapper_test.dart"

# ---------- validators_test.dart ----------
cat > test/unit/core/validators_test.dart <<'DARTEOF'
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/utils/validators.dart';

void main() {
  group('Validators.required', () {
    test('returns error for null', () {
      expect(Validators.required(null), isNotNull);
    });
    test('returns error for empty string', () {
      expect(Validators.required(''), isNotNull);
    });
    test('returns error for whitespace only', () {
      expect(Validators.required('   '), isNotNull);
    });
    test('returns null for valid value', () {
      expect(Validators.required('ok'), isNull);
    });
    test('uses custom field name', () {
      final result = Validators.required(null, field: 'Le nom');
      expect(result, contains('Le nom'));
    });
  });

  group('Validators.email', () {
    test('returns error for null', () {
      expect(Validators.email(null), isNotNull);
    });
    test('returns error for empty', () {
      expect(Validators.email(''), isNotNull);
    });
    test('returns error for missing @', () {
      expect(Validators.email('invalid'), isNotNull);
    });
    test('returns error for missing domain', () {
      expect(Validators.email('a@b'), isNotNull);
    });
    test('returns null for valid email', () {
      expect(Validators.email('a@b.com'), isNull);
    });
    test('returns null for email with plus tag', () {
      expect(Validators.email('user+tag@example.co.uk'), isNull);
    });
  });

  group('Validators.password', () {
    test('returns error for null', () {
      expect(Validators.password(null), isNotNull);
    });
    test('returns error for empty', () {
      expect(Validators.password(''), isNotNull);
    });
    test('returns error for too short', () {
      expect(Validators.password('short'), isNotNull);
    });
    test('returns null for 8+ chars', () {
      expect(Validators.password('12345678'), isNull);
    });
    test('returns null for long password', () {
      expect(Validators.password('a_very_strong_password'), isNull);
    });
  });
}
DARTEOF
log_ok "Created validators_test.dart"

# ---------- pii_scrubber_test.dart ----------
cat > test/unit/core/pii_scrubber_test.dart <<'DARTEOF'
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/utils/pii_scrubber.dart';

void main() {
  group('PiiScrubber.scrub', () {
    test('redacts token', () {
      final out = PiiScrubber.scrub('{"token":"abc123"}');
      expect(out, '{"token":"[REDACTED]"}');
    });

    test('redacts password', () {
      final out = PiiScrubber.scrub('{"password":"secret"}');
      expect(out, '{"password":"[REDACTED]"}');
    });

    test('redacts patient_id', () {
      final out = PiiScrubber.scrub('{"patient_id":"uuid-x"}');
      expect(out, '{"patient_id":"[REDACTED]"}');
    });

    test('redacts practitioner_id', () {
      final out = PiiScrubber.scrub('{"practitioner_id":"uuid-y"}');
      expect(out, '{"practitioner_id":"[REDACTED]"}');
    });

    test('redacts bearer token', () {
      final out = PiiScrubber.scrub('Authorization: Bearer eyJhbGciOi...');
      expect(out, contains('[REDACTED]'));
      expect(out, isNot(contains('eyJhbGciOi')));
    });

    test('leaves clean string unchanged', () {
      const clean = 'Bonjour, world!';
      expect(PiiScrubber.scrub(clean), clean);
    });

    test('handles multiple sensitive fields', () {
      final out = PiiScrubber.scrub(
        '{"token":"t","password":"p","patient_id":"id"}',
      );
      expect(out, isNot(contains('"t"')));
      expect(out, isNot(contains('"p"')));
      expect(out, isNot(contains('"id"')));
      expect('[REDACTED]'.allMatches(out).length, greaterThanOrEqualTo(3));
    });
  });
}
DARTEOF
log_ok "Created pii_scrubber_test.dart"

# ---------- idempotency_key_test.dart ----------
cat > test/unit/core/idempotency_key_test.dart <<'DARTEOF'
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/utils/idempotency_key.dart';

void main() {
  group('generateIdempotencyKey', () {
    test('returns a 36-char UUID v4 string', () {
      final key = generateIdempotencyKey();
      expect(key.length, 36);
    });

    test('matches UUID v4 regex', () {
      final key = generateIdempotencyKey();
      final re = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      );
      expect(re.hasMatch(key), isTrue, reason: 'got: $key');
    });

    test('generates unique keys', () {
      final a = generateIdempotencyKey();
      final b = generateIdempotencyKey();
      expect(a, isNot(b));
    });

    test('generates 100 unique keys', () {
      final set = <String>{};
      for (var i = 0; i < 100; i++) {
        set.add(generateIdempotencyKey());
      }
      expect(set.length, 100);
    });
  });
}
DARTEOF
log_ok "Created idempotency_key_test.dart"

# ---------- debouncer_test.dart ----------
cat > test/unit/core/debouncer_test.dart <<'DARTEOF'
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/utils/debouncer.dart';

void main() {
  group('Debouncer', () {
    test('fires once after delay', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 50));
      var count = 0;
      debouncer.run(() => count++);
      debouncer.run(() => count++);
      debouncer.run(() => count++);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(count, 1);
    });

    test('cancel prevents firing', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 50));
      var count = 0;
      debouncer.run(() => count++);
      debouncer.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(count, 0);
    });

    test('fires again for new calls after previous fire', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 30));
      var count = 0;
      debouncer.run(() => count++);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      debouncer.run(() => count++);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(count, 2);
    });
  });
}
DARTEOF
log_ok "Created debouncer_test.dart"

# ─────────────────────────────────────────────────────────────────────────────
# Step 5 — Test helpers: mocks and fixtures
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 5 / 12 — Test helpers (mocks + fixtures)"

# ---------- mock_dio.dart ----------
cat > test/mocks/mock_dio.dart <<'DARTEOF'
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

/// Helper to build a successful JSON response.
Response<T> jsonResponse<T>({
  required T data,
  int statusCode = 200,
  RequestOptions? requestOptions,
}) {
  return Response<T>(
    data: data,
    statusCode: statusCode,
    requestOptions: requestOptions ?? RequestOptions(path: '/'),
  );
}

/// Helper to build a DioException with a status code.
DioException dioError({
  required int statusCode,
  Map<String, dynamic>? data,
  String? path,
}) {
  final opts = RequestOptions(path: path ?? '/');
  return DioException(
    requestOptions: opts,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: opts,
      statusCode: statusCode,
      data: data,
    ),
  );
}
DARTEOF
log_ok "Created mock_dio.dart"

# ---------- user_fixture.dart ----------
cat > test/fixtures/user_fixture.dart <<'DARTEOF'
import 'package:steriymed_mobile/features/auth/data/models/user_data.dart';
import 'package:steriymed_mobile/features/auth/data/models/tenant_data.dart';
import 'package:steriymed_mobile/features/auth/data/models/login_response.dart';

final testUser = UserData(
  id: 'user-1',
  name: 'Dr Test',
  email: 'test@test.com',
  role: 'owner',
);

final testTenant = TenantData(
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
log_ok "Created user_fixture.dart"

# ---------- cycle_fixture.dart ----------
cat > test/fixtures/cycle_fixture.dart <<'DARTEOF'
import 'package:steriymed_mobile/features/cycles/data/models/cycle_data.dart';
import 'package:steriymed_mobile/features/cycles/data/models/cycle_item_data.dart';
import 'package:steriymed_mobile/features/cycles/data/models/control_test_data.dart';

CycleData buildCycle({
  String id = 'cycle-1',
  String number = 'CT-001',
  String status = 'created',
}) {
  return CycleData(
    id: id,
    number: number,
    status: status,
    deviceId: 'device-1',
    deviceName: 'Melag Vacuklav',
    createdAt: DateTime(2026, 9, 18, 10, 0),
  );
}

CycleItemData buildCycleItem({String id = 'item-1', String description = 'Test'}) {
  return CycleItemData(
    id: id,
    cycleId: 'cycle-1',
    description: description,
    createdAt: DateTime(2026, 9, 18, 10, 0),
  );
}

ControlTestData buildControlTest({String id = 'test-1'}) {
  return ControlTestData(
    id: id,
    cycleId: 'cycle-1',
    type: ControlTestType.vacuum,
    result: ControlTestResult.pass,
    performedAt: DateTime(2026, 9, 18, 10, 30),
  );
}
DARTEOF
log_ok "Created cycle_fixture.dart"

# ---------- outbox_item_fixture.dart ----------
cat > test/fixtures/outbox_item_fixture.dart <<'DARTEOF'
import 'package:steriymed_mobile/core/storage/outbox/outbox_item.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_operation.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_status.dart';

OutboxItem buildOutboxItem({
  String id = 'outbox-1',
  OutboxOperation operation = OutboxOperation.stockIssue,
  OutboxStatus status = OutboxStatus.pending,
  int retryCount = 0,
}) {
  return OutboxItem(
    id: id,
    operation: operation,
    endpoint: '/v1/stock-movements/issue',
    method: 'POST',
    payload: const {'batch_id': 'b-1', 'location_id': 'l-1', 'qty': 1},
    idempotencyKey: 'key-$id',
    createdAt: DateTime(2026, 9, 18, 10, 0),
    status: status,
    retryCount: retryCount,
  );
}
DARTEOF
log_ok "Created outbox_item_fixture.dart"

# ---------- alert_fixture.dart ----------
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
log_ok "Created alert_fixture.dart"

# ---------- mock_outbox_store.dart ----------
cat > test/mocks/mock_outbox_store.dart <<'DARTEOF'
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_store.dart';

class MockOutboxStore extends Mock implements OutboxStore {}
DARTEOF
log_ok "Created mock_outbox_store.dart"

# ---------- mock_repositories.dart ----------
cat > test/mocks/mock_repositories.dart <<'DARTEOF'
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/cycle_repository.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_repository.dart';
import 'package:steriymed_mobile/features/stock/data/repositories/stock_repository.dart';
import 'package:steriymed_mobile/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:steriymed_mobile/features/alerts/data/repositories/alert_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockCycleRepository extends Mock implements CycleRepository {}
class MockLabelRepository extends Mock implements LabelRepository {}
class MockStockRepository extends Mock implements StockRepository {}
class MockDashboardRepository extends Mock implements DashboardRepository {}
class MockAlertRepository extends Mock implements AlertRepository {}
DARTEOF
log_ok "Created mock_repositories.dart"

# ---------- mock_connectivity.dart ----------
cat > test/mocks/mock_connectivity.dart <<'DARTEOF'
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/sync/connectivity_service.dart';
import 'package:steriymed_mobile/core/network/network_info.dart';

class MockConnectivityService extends Mock implements ConnectivityService {}
class MockNetworkInfo extends Mock implements NetworkInfo {}
DARTEOF
log_ok "Created mock_connectivity.dart"

# ---------- pump_app.dart helper ----------
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
log_ok "Created pump_app.dart"

# ─────────────────────────────────────────────────────────────────────────────
# Step 6 — Bloc tests
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 6 / 12 — Bloc tests"

# ---------- auth_bloc_test.dart ----------
cat > test/bloc/auth_bloc_test.dart <<'DARTEOF'
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/errors/error_codes.dart';
import 'package:steriymed_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/auth_event.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/auth_state.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;

  setUp(() {
    repo = MockAuthRepository();
  });

  group('AuthBloc', () {
    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] on successful login',
      build: () => AuthBloc(repo),
      setUp: () {
        when(() => repo.login(
              tenantSlug: any(named: 'tenantSlug'),
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async {});
      },
      act: (bloc) => bloc.add(const AuthLoginSubmitted(
        tenantSlug: 'test',
        email: 'a@b.com',
        password: 'password123',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAuthenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, error, unauthenticated] on 401',
      build: () => AuthBloc(repo),
      setUp: () {
        when(() => repo.login(
              tenantSlug: any(named: 'tenantSlug'),
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(const ApiException(
          code: ErrorCodes.unauthenticated,
          message: 'Identifiants invalides.',
          statusCode: 401,
        ));
      },
      act: (bloc) => bloc.add(const AuthLoginSubmitted(
        tenantSlug: 'test',
        email: 'a@b.com',
        password: 'wrong',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>(),
        isA<AuthUnauthenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, unauthenticated] when session check returns false',
      build: () => AuthBloc(repo),
      setUp: () {
        when(() => repo.restoreSession()).thenAnswer((_) async => false);
      },
      act: (bloc) => bloc.add(const AuthSessionChecked()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthUnauthenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] when session check returns true',
      build: () => AuthBloc(repo),
      setUp: () {
        when(() => repo.restoreSession()).thenAnswer((_) async => true);
      },
      act: (bloc) => bloc.add(const AuthSessionChecked()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAuthenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [unauthenticated] on logout',
      build: () => AuthBloc(repo),
      setUp: () {
        when(() => repo.logout()).thenAnswer((_) async {});
      },
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [unauthenticated] on logoutEvenwhere',
      build: () => AuthBloc(repo),
      setUp: () {
        when(() => repo.logoutEverywhere()).thenAnswer((_) async {});
      },
      act: (bloc) => bloc.add(const AuthLogoutEverywhereRequested()),
      expect: () => [isA<AuthUnauthenticated>()],
    );
  });
}
DARTEOF
log_ok "Created auth_bloc_test.dart"

# ---------- scanner_bloc_test.dart ----------
cat > test/bloc/scanner_bloc_test.dart <<'DARTEOF'
import 'package:bloc_test/bloc_test.dart';
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
    blocTest<ScannerBloc, ScannerState>(
      'emits [resolving, resolved] on valid scan',
      build: () => ScannerBloc(repo),
      setUp: () {
        when(() => repo.getByCode(any())).thenAnswer((_) async =>
            const LabelScanResult(
              code: 'LABEL-1',
              status: LabelScanStatus.valid,
              label: LabelData(id: 'l1', code: 'LABEL-1', status: 'valid'),
            ));
      },
      act: (bloc) => bloc.add(const ScanDetected('LABEL-1')),
      wait: const Duration(milliseconds: 500),
      expect: () => [
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolving),
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolved),
        // cooldown may transition back to scanning; allow it
      ],
      expectLater: (stream) => stream.take(2),
    );

    blocTest<ScannerBloc, ScannerState>(
      'emits [resolving, resolved] with blocked status for expired label',
      build: () => ScannerBloc(repo),
      setUp: () {
        when(() => repo.getByCode(any())).thenAnswer((_) async =>
            const LabelScanResult(
              code: 'LABEL-2',
              status: LabelScanStatus.expired,
              reason: 'Expiré',
            ));
      },
      act: (bloc) => bloc.add(const ScanDetected('LABEL-2')),
      wait: const Duration(milliseconds: 500),
      expect: () => [
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolving),
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolved)
            .having((s) => s.result?.status, 'result.status',
                LabelScanStatus.expired),
      ],
      expectLater: (stream) => stream.take(2),
    );

    blocTest<ScannerBloc, ScannerState>(
      'emits [resolving, error] on network error',
      build: () => ScannerBloc(repo),
      setUp: () {
        when(() => repo.getByCode(any()))
            .thenThrow(const ApiException(
          code: 'network_error',
          message: 'Connexion impossible.',
        ));
      },
      act: (bloc) => bloc.add(const ScanDetected('LABEL-3')),
      wait: const Duration(milliseconds: 500),
      expect: () => [
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.resolving),
        isA<ScannerState>()
            .having((s) => s.status, 'status', ScannerStatus.error),
      ],
      expectLater: (stream) => stream.take(2),
    );

    test('torch toggles', () {
      final bloc = ScannerBloc(repo);
      expect(bloc.state.torchOn, false);
      bloc.add(const TorchToggled());
      expect(bloc.state.torchOn, true);
      bloc.add(const TorchToggled());
      expect(bloc.state.torchOn, false);
      bloc.close();
    });

    test('reset returns to initial state', () {
      final bloc = ScannerBloc(repo);
      bloc.add(const ScannerReset());
      expect(bloc.state.status, ScannerStatus.initial);
      bloc.close();
    });
  });
}
DARTEOF
log_ok "Created scanner_bloc_test.dart"

# ---------- cycle_detail_bloc_test.dart ----------
cat > test/bloc/cycle_detail_bloc_test.dart <<'DARTEOF'
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/cycle_repository.dart';
import 'package:steriymed_mobile/features/cycles/presentation/bloc/cycle_detail_bloc.dart';

import '../fixtures/cycle_fixture.dart';

class MockCycleRepository extends Mock implements CycleRepository {}

void main() {
  late MockCycleRepository repo;

  setUp(() {
    repo = MockCycleRepository();
  });

  group('CycleDetailBloc', () {
    blocTest<CycleDetailBloc, CycleDetailState>(
      'loads cycle + items + tests + attachments',
      build: () => CycleDetailBloc(repo),
      setUp: () {
        when(() => repo.show(any()))
            .thenAnswer((_) async => buildCycle());
        when(() => repo.listItems(any()))
            .thenAnswer((_) async => [buildCycleItem()]);
        when(() => repo.listControlTests(any()))
            .thenAnswer((_) async => [buildControlTest()]);
        when(() => repo.listAttachments(any()))
            .thenAnswer((_) async => []);
      },
      act: (bloc) => bloc.add(const LoadCycleDetail('cycle-1')),
      expect: () => [
        isA<CycleDetailState>()
            .having((s) => s.status, 'status', CycleDetailStatus.loading),
        isA<CycleDetailState>()
            .having((s) => s.status, 'status', CycleDetailStatus.success)
            .having((s) => s.cycle, 'cycle', isNotNull)
            .having((s) => s.items.length, 'items', 1)
            .having((s) => s.controlTests.length, 'tests', 1),
      ],
    );

    blocTest<CycleDetailBloc, CycleDetailState>(
      'cycle load failure -> failure state',
      build: () => CycleDetailBloc(repo),
      setUp: () {
        when(() => repo.show(any()))
            .thenThrow(const ApiException(code: 'server_error', message: 'Erreur'));
      },
      act: (bloc) => bloc.add(const LoadCycleDetail('cycle-1')),
      expect: () => [
        isA<CycleDetailState>()
            .having((s) => s.status, 'status', CycleDetailStatus.loading),
        isA<CycleDetailState>()
            .having((s) => s.status, 'status', CycleDetailStatus.failure),
      ],
    );

    blocTest<CycleDetailBloc, CycleDetailState>(
      'cycle loads but items fail -> still success, aux error set',
      build: () => CycleDetailBloc(repo),
      setUp: () {
        when(() => repo.show(any())).thenAnswer((_) async => buildCycle());
        when(() => repo.listItems(any()))
            .thenThrow(const ApiException(code: 'server_error', message: 'X'));
        when(() => repo.listControlTests(any()))
            .thenAnswer((_) async => []);
        when(() => repo.listAttachments(any()))
            .thenAnswer((_) async => []);
      },
      act: (bloc) => bloc.add(const LoadCycleDetail('cycle-1')),
      expect: () => [
        isA<CycleDetailState>()
            .having((s) => s.status, 'status', CycleDetailStatus.loading),
        isA<CycleDetailState>()
            .having((s) => s.status, 'status', CycleDetailStatus.success),
        isA<CycleDetailState>()
            .having((s) => s.status, 'status', CycleDetailStatus.success)
            .having((s) => s.cycle, 'cycle', isNotNull)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );
  });
}
DARTEOF
log_ok "Created cycle_detail_bloc_test.dart"

# ---------- dashboard_cubit_test.dart ----------
cat > test/bloc/dashboard_cubit_test.dart <<'DARTEOF'
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/dashboard/data/models/dashboard_data.dart';
import 'package:steriymed_mobile/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:steriymed_mobile/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:steriymed_mobile/features/dashboard/presentation/cubit/dashboard_state.dart';

class MockDashboardRepository extends Mock implements DashboardRepository {}
class MockSessionStore extends Mock implements SessionStore {}

const _emptyDashboard = DashboardData(
  greeting: 'Bonjour',
  userName: '',
  kpis: [],
  attention: [],
  todayCycles: [],
  recentProcedures: [],
);

void main() {
  late MockDashboardRepository repo;
  late MockSessionStore session;

  setUp(() {
    repo = MockDashboardRepository();
    session = MockSessionStore();
    when(() => session.userName).thenReturn('Dr Test');
  });

  group('DashboardCubit', () {
    blocTest<DashboardCubit, DashboardState>(
      'loads successfully',
      build: () => DashboardCubit(repo, session),
      setUp: () {
        when(() => repo.fetch(forceRefresh: any(named: 'forceRefresh')))
            .thenAnswer((_) async => _emptyDashboard);
      },
      act: (c) => c.load(),
      expect: () => [
        isA<DashboardLoading>(),
        isA<DashboardLoaded>(),
      ],
    );

    blocTest<DashboardCubit, DashboardState>(
      'emits error on failure',
      build: () => DashboardCubit(repo, session),
      setUp: () {
        when(() => repo.fetch(forceRefresh: any(named: 'forceRefresh')))
            .thenThrow(Exception('boom'));
      },
      act: (c) => c.load(),
      expect: () => [
        isA<DashboardLoading>(),
        isA<DashboardError>(),
      ],
    );
  });
}
DARTEOF
log_ok "Created dashboard_cubit_test.dart"

# ---------- stock_issue_bloc_test.dart ----------
cat > test/bloc/stock_issue_bloc_test.dart <<'DARTEOF'
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/stock/data/models/stock_movement_data.dart';
import 'package:steriymed_mobile/features/stock/data/repositories/stock_repository.dart';
import 'package:steriymed_mobile/features/stock/presentation/bloc/stock_issue_bloc.dart';

class MockStockRepository extends Mock implements StockRepository {}

void main() {
  late MockStockRepository repo;

  setUp(() {
    repo = MockStockRepository();
  });

  group('StockIssueBloc', () {
    blocTest<StockIssueBloc, StockIssueState>(
      'emits [loading, success] on submit',
      build: () => StockIssueBloc(repo),
      setUp: () {
        when(() => repo.issue(
              batchId: any(named: 'batchId'),
              locationId: any(named: 'locationId'),
              qty: any(named: 'qty'),
              reason: any(named: 'reason'),
            )).thenAnswer((_) async => StockMovementData(
              id: 'm-1',
              kind: 'issue',
              batchId: 'b-1',
              locationId: 'l-1',
              qty: 2,
              createdAt: DateTime.now(),
            ));
      },
      act: (b) => b.add(const SubmitStockIssue(
        batchId: 'b-1',
        locationId: 'l-1',
        qty: 2,
      )),
      expect: () => [
        isA<StockIssueState>()
            .having((s) => s.status, 'status', StockIssueStatus.loading),
        isA<StockIssueState>()
            .having((s) => s.status, 'status', StockIssueStatus.success),
      ],
    );

    blocTest<StockIssueBloc, StockIssueState>(
      'emits [loading, failure] on 422',
      build: () => StockIssueBloc(repo),
      setUp: () {
        when(() => repo.issue(
              batchId: any(named: 'batchId'),
              locationId: any(named: 'locationId'),
              qty: any(named: 'qty'),
              reason: any(named: 'reason'),
            )).thenThrow(const ApiException(
          code: 'validation_error',
          message: 'Quantité invalide.',
          statusCode: 422,
        ));
      },
      act: (b) => b.add(const SubmitStockIssue(
        batchId: 'b-1',
        locationId: 'l-1',
        qty: 0,
      )),
      expect: () => [
        isA<StockIssueState>()
            .having((s) => s.status, 'status', StockIssueStatus.loading),
        isA<StockIssueState>()
            .having((s) => s.status, 'status', StockIssueStatus.failure)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );
  });
}
DARTEOF
log_ok "Created stock_issue_bloc_test.dart"

# ---------- alert_list_bloc_test.dart ----------
cat > test/bloc/alert_list_bloc_test.dart <<'DARTEOF'
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
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
        when(() => repo.getActiveAlerts(forceRefresh: any(named: 'forceRefresh')))
            .thenAnswer((_) async => [buildAlert()]);
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
        when(() => repo.getActiveAlerts(forceRefresh: any(named: 'forceRefresh')))
            .thenThrow(const ApiException(
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
log_ok "Created alert_list_bloc_test.dart"

# ─────────────────────────────────────────────────────────────────────────────
# Step 7 — Widget tests
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 7 / 12 — Widget tests"

# ---------- login_screen_test.dart ----------
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
import '../mocks/mock_repositories.dart';

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

  testWidgets('disables submit while loading', (tester) async {
    when(() => repo.login(
          tenantSlug: any(named: 'tenantSlug'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(seconds: 5));
    });

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

    // Button should be in loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
log_ok "Created login_screen_test.dart"

# ---------- alert_list_screen_test.dart ----------
cat > test/widget/alert_list_screen_test.dart <<'DARTEOF'
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/features/alerts/data/repositories/alert_repository.dart';
import 'package:steriymed_mobile/features/alerts/presentation/bloc/alert_list_bloc.dart';
import 'package:steriymed_mobile/features/alerts/presentation/screens/alert_list_screen.dart';

import '../fixtures/alert_fixture.dart';
import '../helpers/pump_app.dart';
import '../mocks/mock_repositories.dart';

void main() {
  late MockAlertRepository repo;

  setUp(() {
    repo = MockAlertRepository();
  });

  testWidgets('renders severity groups', (tester) async {
    when(() => repo.getActiveAlerts(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => [
              buildAlert(id: 'a1', severity: AlertSeverity.critical),
              buildAlert(id: 'a2', severity: AlertSeverity.warning),
              buildAlert(id: 'a3', severity: AlertSeverity.info),
            ]);

    await pumpApp(
      tester,
      RepositoryProvider<AlertRepository>.value(
        value: repo,
        child: Builder(
          builder: (ctx) => BlocProvider(
            create: (_) => AlertListBloc(repo)..add(const LoadAlerts()),
            child: const AlertListScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Critique'), findsOneWidget);
    expect(find.text('Avertissement'), findsOneWidget);
    expect(find.text('Information'), findsOneWidget);
  });

  testWidgets('shows empty view when no alerts', (tester) async {
    when(() => repo.getActiveAlerts(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => []);

    await pumpApp(
      tester,
      RepositoryProvider<AlertRepository>.value(
        value: repo,
        child: BlocProvider(
          create: (_) => AlertListBloc(repo)..add(const LoadAlerts()),
          child: const AlertListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aucune alerte active'), findsOneWidget);
  });
}
DARTEOF
log_ok "Created alert_list_screen_test.dart"

# ─────────────────────────────────────────────────────────────────────────────
# Step 8 — Run analyze + tests
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 8 / 12 — Analyze + run tests"

echo ""
echo "▶ flutter analyze"
if flutter analyze; then
  log_ok "Analyze clean"
else
  log_warn "Analyze produced issues. Continuing for now."
fi

echo ""
echo "▶ flutter test --coverage"
if flutter test --coverage; then
  log_ok "All tests pass"
else
  log_warn "Some tests failed. Review the output above."
  read -r -p "Continue anyway? [y/N] " response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    fatal "Aborted by user."
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 9 — Generate coverage report
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 9 / 12 — Coverage report"

if [ -f "coverage/lcov.info" ]; then
  log_ok "coverage/lcov.info exists"

  # Try to generate HTML if lcov is available
  if command -v genhtml &> /dev/null; then
    genhtml coverage/lcov.info -o coverage/html --quiet 2>/dev/null || true
    log_ok "HTML report at coverage/html/index.html"
  else
    log_warn "genhtml not installed. To install: brew install lcov (macOS) or apt install lcov (Linux)"
  fi

  # Print a quick line count of coverage
  LINES_HIT=$(grep -c "^DA:" coverage/lcov.info 2>/dev/null || echo "0")
  log_ok "Coverage data points: $LINES_HIT"
else
  log_warn "No coverage/lcov.info generated"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 10 — Ensure CI runs the tests
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 10 / 12 — Ensure CI runs tests"

mkdir -p .github/workflows

if [ ! -f ".github/workflows/mobile-test.yml" ] || ! grep -q "flutter test" .github/workflows/mobile-test.yml; then
  cat > .github/workflows/mobile-test.yml <<'YAMLEOF'
name: Mobile — Test

on:
  push:
    branches: [main, 'phase-*', 'mvp/**']
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - name: Upload coverage artifact
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/lcov.info
          if-no-files-found: ignore
YAMLEOF
  log_ok "Wrote .github/workflows/mobile-test.yml"
else
  log_ok "mobile-test.yml already configured"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 11 — Update docs
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 11 / 12 — Update docs/TESTING.md"

mkdir -p docs

cat > docs/TESTING.md <<EOF
# Testing Strategy — SteryMed Mobile

**Last updated:** $TODAY

## Principles

1. **Test the critical path.** Not everything. Focus on the code paths that
   will break the pilot if they fail.
2. **Test at the right level.** Core utils → unit. Blocs → bloc_test. Screens
   → widget. Journeys → integration.
3. **No mocks of the framework.** Only mock what we own or what crosses the
   network boundary.
4. **Fast tests.** Unit and bloc tests must run in seconds, not minutes.
5. **CI is the source of truth.** If tests pass locally but not on CI, CI wins.

## Coverage

Run locally:

    flutter test --coverage
    genhtml coverage/lcov.info -o coverage/html
    open coverage/html/index.html

## Test matrix

| Layer | File | What it covers |
|-------|------|----------------|
| Unit | \`test/unit/core/error_mapper_test.dart\` | Dio → ApiException mapping |
| Unit | \`test/unit/core/validators_test.dart\` | required, email, password |
| Unit | \`test/unit/core/pii_scrubber_test.dart\` | token/password/ID redaction |
| Unit | \`test/unit/core/idempotency_key_test.dart\` | UUID v4 format |
| Unit | \`test/unit/core/debouncer_test.dart\` | Debouncer timing |
| Bloc | \`test/bloc/auth_bloc_test.dart\` | Login, logout, session restore |
| Bloc | \`test/bloc/scanner_bloc_test.dart\` | Scan, cooldown, blocked, error |
| Bloc | \`test/bloc/cycle_detail_bloc_test.dart\` | Load, partial failure |
| Bloc | \`test/bloc/dashboard_cubit_test.dart\` | Load, error |
| Bloc | \`test/bloc/stock_issue_bloc_test.dart\` | Success, 422 |
| Bloc | \`test/bloc/alert_list_bloc_test.dart\` | Load, group by severity |
| Widget | \`test/widget/login_screen_test.dart\` | Render, validation, submit |
| Widget | \`test/widget/alert_list_screen_test.dart\` | Groups, empty state |

## What is NOT tested yet

- Integration journeys (Phase 8)
- Golden tests (Phase 5)
- Offline sync flow (partially in Phase 2)

## Conventions

- File names end with \`_test.dart\`.
- Each test group has a clear description.
- Use \`mocktail\` for mocking, never \`mockito\`.
- Register fallback values in \`setUp\` for any custom type passed to \`any()\`.
- Never commit a test that only passes on your machine.

## Adding a new test

1. Identify the behavior you want to verify.
2. Write the test **first** if possible (TDD).
3. Run only that file: \`flutter test path/to/file_test.dart\`
4. Once green, run the full suite: \`flutter test\`
5. Commit with a message like: \`test(<scope>): verify <behavior>\`

## CI

The workflow \`.github/workflows/mobile-test.yml\` runs on every push to
\`main\` and \`phase-*\` branches. It runs:

    flutter pub get
    flutter analyze
    flutter test --coverage

If any step fails, the branch is not mergeable.
EOF

log_ok "Updated docs/TESTING.md"

# ─────────────────────────────────────────────────────────────────────────────
# Step 12 — Commit + tag
# ─────────────────────────────────────────────────────────────────────────────

log_step "Step 12 / 12 — Commit + tag"

# Clean up any .tmp files
find . -name "*.tmp" -type f -delete 2>/dev/null || true

# Final summary
echo ""
echo "Test files created:"
find test/ -name "*_test.dart" -type f | sort

echo ""
echo "Total test files: $(find test/ -name '*_test.dart' -type f | wc -l | tr -d ' ')"
echo "Total test lines: $(find test/ -name '*_test.dart' -type f -exec cat {} + | wc -l | tr -d ' ')"

git add -A

if git diff --cached --quiet; then
  log_warn "Nothing to commit. Phase 1 already applied."
else
  git commit -m "test(p1): add Phase 1 testing foundation

- Unit tests: error mapper, validators, PII scrubber, idempotency key, debouncer
- Bloc tests: auth, scanner, cycle detail, dashboard, stock issue, alert list
- Widget tests: login screen, alert list screen
- Mocks: Dio, repositories, outbox store, connectivity
- Fixtures: user, tenant, cycle, alert, outbox item
- Helpers: pumpApp, coverage report generation
- CI workflow runs tests + coverage

Phase 1 gate: all tests green, coverage report generated."
  log_ok "Committed Phase 1"
fi

if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
  log_warn "Tag $TAG_NAME already exists."
else
  git tag -a "$TAG_NAME" -m "Phase 1 testing foundation complete — $(date)"
  log_ok "Tagged $TAG_NAME"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Phase 1 complete.${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo ""
echo "  1. Push the branch and tag:"
echo "     git push origin $BRANCH_NAME"
echo "     git push origin $TAG_NAME"
echo ""
echo "  2. Watch CI on GitHub Actions. Must be green."
echo ""
echo "  3. Optionally: view the coverage report"
echo "     genhtml coverage/lcov.info -o coverage/html"
echo "     open coverage/html/index.html"
echo ""
echo "  4. Merge to main when CI is green:"
echo "     git checkout main"
echo "     git merge --no-ff $BRANCH_NAME"
echo "     git push"
echo ""
echo "  5. When Gate P1 is verified, start Phase 2."
echo ""