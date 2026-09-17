#!/usr/bin/env bash
# =============================================================================
# SteryMed Mobile — Full UI Deployment Script
# Run from project root: bash deploy_ui.sh
# Idempotent: re-running overwrites files with the same content.
# =============================================================================
set -euo pipefail

PROJECT_ROOT="$(pwd)"

if [[ ! -f "$PROJECT_ROOT/pubspec.yaml" ]]; then
  echo "❌  Run this from the Flutter project root (pubspec.yaml not found)."
  exit 1
fi

if ! grep -q "name: steriymed_mobile" "$PROJECT_ROOT/pubspec.yaml"; then
  echo "❌  This is not the SteryMed project."
  exit 1
fi

echo "✅  Project root: $PROJECT_ROOT"
echo "═══════════════════════════════════════════════════════════════"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 0 — Purge dead code
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Phase 0 — Purging dead code"
rm -rf lib/features/onboarding
rm -rf lib/features/prosthetic
rm -f  lib/features/shell/presentation/widgets/sync_indicator.dart
rm -f  lib/features/shell/presentation/widgets/role_aware_nav.dart
rm -f  lib/core/sync/network_info_import.dart
rm -f  lib/core/storage/outbox/outbox_repository.dart
echo "   ✔ purged"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 1 — Core
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Phase 1 — Core layer"
mkdir -p lib/core/config lib/core/router lib/core/storage lib/core/sync \
         lib/core/network/interceptors lib/di

cat > lib/core/config/api_endpoints.dart << 'DART_EOF'
abstract final class ApiEndpoints {
  static const _v1 = '/v1';

  // Auth
  static const login = '$_v1/auth/login';
  static const register = '$_v1/tenants';
  static const logout = '$_v1/auth/logout';
  static const logoutEverywhere = '$_v1/auth/tokens';
  static const me = '$_v1/me';

  // Alerts
  static const alerts = '$_v1/alerts';
  static String alertResolve(String id) => '$_v1/alerts/$id/resolve';

  // Labels
  static String labelByCode(String code) => '$_v1/labels/$code';
  static String labelUsage(String labelId) => '$_v1/labels/$labelId/usage';

  // Patients
  static const patients = '$_v1/patients';
  static String patient(String id) => '$_v1/patients/$id';

  // Cycles
  static const cycles = '$_v1/cycles';
  static String cycle(String id) => '$_v1/cycles/$id';
  static String cycleStart(String id) => '$_v1/cycles/$id/start';
  static String cycleComplete(String id) => '$_v1/cycles/$id/complete';
  static String cycleSubmit(String id) => '$_v1/cycles/$id/submit-for-release';
  static String cycleRelease(String id) => '$_v1/cycles/$id/release';
  static String cycleItems(String id) => '$_v1/cycles/$id/items';
  static String cycleItem(String id, String itemId) =>
      '$_v1/cycles/$id/items/$itemId';
  static String cycleControlTests(String id) => '$_v1/cycles/$id/control-tests';
  static String cycleAttachments(String id) => '$_v1/cycles/$id/attachments';
  static String cycleAttachment(String id, int mediaId) =>
      '$_v1/cycles/$id/attachments/$mediaId';

  // Stock
  static const stockLevels = '$_v1/stock-levels';
  static const stockIssue = '$_v1/stock-movements/issue';
  static const stockAdjust = '$_v1/stock-movements/adjust';
  static const stockTransfer = '$_v1/stock-movements/transfer';

  // Audit
  static const auditEvents = '$_v1/audit-events';

  // Compliance
  static const nonConformities = '$_v1/non-conformities';
  static String nonConformity(String id) => '$_v1/non-conformities/$id';
  static String nonConformityResolve(String id) =>
      '$_v1/non-conformities/$id/resolve';

  // Sites
  static const sites = '$_v1/sites';

  // Team
  static const invitations = '$_v1/invitations';
  static String invitation(String id) => '$_v1/invitations/$id';
  static String member(String tenantUserId) => '$_v1/members/$tenantUserId';
}
DART_EOF

cat > lib/core/router/routes.dart << 'DART_EOF'
abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const cameraPermission = '/camera-permission';

  static const dashboard = '/app/dashboard';
  static const scanner = '/app/scanner';
  static const cycles = '/app/cycles';
  static const alerts = '/app/alerts';
  static const settings = '/app/settings';

  static const cyclesCreate = '/app/cycles/create';
  static String cyclesDetail(String id) => '/app/cycles/$id';
  static String cyclesItems(String id) => '/app/cycles/$id/items';
  static String cyclesControlTests(String id) => '/app/cycles/$id/control-tests';
  static String cyclesAttachments(String id) => '/app/cycles/$id/attachments';
  static String cyclesRelease(String id) => '/app/cycles/$id/release';

  static const stock = '/app/stock';
  static const stockIssue = '/app/stock/issue';
  static const stockAdjust = '/app/stock/adjust';
  static const stockTransfer = '/app/stock/transfer';

  static String labelsDetail(String code) => '/app/labels/$code';
  static String labelsBlocked(String code) => '/app/labels/$code/blocked';
  static String labelsUsage(String labelId) => '/app/labels/$labelId/usage';

  static const patients = '/app/patients';
  static const audit = '/app/audit';
  static const team = '/app/team';
  static String teamDetail(String id) => '/app/team/$id';
  static const sites = '/app/sites';
  static const nonConformities = '/app/non-conformities';
  static const dataExports = '/app/data-exports';
  static const sync = '/app/sync';
  static const about = '/app/about';
}
DART_EOF

cat > lib/core/router/route_names.dart << 'DART_EOF'
abstract final class RouteNames {
  static const splash = 'splash';
  static const login = 'login';
  static const register = 'register';
  static const cameraPermission = 'camera-permission';

  static const dashboard = 'dashboard';
  static const scanner = 'scanner';
  static const cycles = 'cycles';
  static const cyclesDetail = 'cycles-detail';
  static const cyclesCreate = 'cycles-create';
  static const cyclesItems = 'cycles-items';
  static const cyclesControlTests = 'cycles-control-tests';
  static const cyclesAttachments = 'cycles-attachments';
  static const cyclesRelease = 'cycles-release';

  static const alerts = 'alerts';
  static const stock = 'stock';
  static const stockIssue = 'stock-issue';
  static const stockAdjust = 'stock-adjust';
  static const stockTransfer = 'stock-transfer';

  static const labelsDetail = 'labels-detail';
  static const labelsBlocked = 'labels-blocked';
  static const labelsUsage = 'labels-usage';

  static const patients = 'patients';
  static const audit = 'audit';
  static const settings = 'settings';
  static const about = 'about';
  static const sync = 'sync';
}
DART_EOF

cat > lib/core/router/app_router.dart << 'DART_EOF'
import 'package:go_router/go_router.dart';

import '../../features/alerts/presentation/screens/alert_list_screen.dart';
import '../../features/auth/presentation/screens/camera_permission_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/compliance/presentation/screens/non_conformities_screen.dart';
import '../../features/cycles/presentation/screens/cycle_attachments_screen.dart';
import '../../features/cycles/presentation/screens/cycle_control_tests_screen.dart';
import '../../features/cycles/presentation/screens/cycle_create_screen.dart';
import '../../features/cycles/presentation/screens/cycle_detail_screen.dart';
import '../../features/cycles/presentation/screens/cycle_items_screen.dart';
import '../../features/cycles/presentation/screens/cycle_list_screen.dart';
import '../../features/cycles/presentation/screens/cycle_release_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/history/presentation/screens/audit_list_screen.dart';
import '../../features/identity/presentation/screens/team_detail_screen.dart';
import '../../features/identity/presentation/screens/team_list_screen.dart';
import '../../features/labels/presentation/screens/label_blocked_screen.dart';
import '../../features/labels/presentation/screens/label_detail_screen.dart';
import '../../features/labels/presentation/screens/label_usage_form_screen.dart';
import '../../features/patients/presentation/screens/patient_search_screen.dart';
import '../../features/reporting/presentation/screens/data_export_request_screen.dart';
import '../../features/scanner/presentation/screens/scanner_screen.dart';
import '../../features/settings/presentation/screens/about_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/shell/presentation/screens/shell_screen.dart';
import '../../features/stock/presentation/screens/stock_adjust_screen.dart';
import '../../features/stock/presentation/screens/stock_issue_screen.dart';
import '../../features/stock/presentation/screens/stock_level_list_screen.dart';
import '../../features/stock/presentation/screens/stock_transfer_screen.dart';
import '../../features/sync/presentation/screens/sync_queue_screen.dart';
import '../../features/tenancy/presentation/screens/site_list_screen.dart';

import 'route_names.dart';
import 'routes.dart';

class AppRouter {
  final bool Function() isAuthenticated;
  final Future<bool> Function() hasStoredToken;

  AppRouter({
    required this.isAuthenticated,
    required this.hasStoredToken,
  });

  late final GoRouter router = GoRouter(
    initialLocation: Routes.splash,
    redirect: (context, state) async {
      final loc = state.matchedLocation;
      final isPublic = loc == Routes.splash ||
          loc == Routes.login ||
          loc == Routes.register ||
          loc == Routes.cameraPermission;

      if (isPublic) return null;
      if (isAuthenticated()) return null;
      if (await hasStoredToken()) return null;
      return Routes.login;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        name: RouteNames.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        name: RouteNames.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        name: RouteNames.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.cameraPermission,
        name: RouteNames.cameraPermission,
        builder: (_, __) => const CameraPermissionScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            name: RouteNames.dashboard,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: Routes.scanner,
            name: RouteNames.scanner,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ScannerScreen()),
          ),
          GoRoute(
            path: Routes.cycles,
            name: RouteNames.cycles,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: CycleListScreen()),
          ),
          GoRoute(
            path: Routes.alerts,
            name: RouteNames.alerts,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AlertListScreen()),
          ),
          GoRoute(
            path: Routes.settings,
            name: RouteNames.settings,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
          GoRoute(
            path: Routes.stock,
            name: RouteNames.stock,
            builder: (_, __) => const StockLevelListScreen(),
          ),
          GoRoute(
            path: Routes.stockIssue,
            name: RouteNames.stockIssue,
            builder: (_, __) => const StockIssueScreen(),
          ),
          GoRoute(
            path: Routes.stockAdjust,
            name: RouteNames.stockAdjust,
            builder: (_, __) => const StockAdjustScreen(),
          ),
          GoRoute(
            path: Routes.stockTransfer,
            name: RouteNames.stockTransfer,
            builder: (_, __) => const StockTransferScreen(),
          ),
          GoRoute(
            path: Routes.patients,
            name: RouteNames.patients,
            builder: (_, __) => const PatientSearchScreen(),
          ),
          GoRoute(
            path: Routes.cyclesCreate,
            name: RouteNames.cyclesCreate,
            builder: (_, __) => const CycleCreateScreen(),
          ),
          GoRoute(
            path: '/app/cycles/:id',
            name: RouteNames.cyclesDetail,
            builder: (_, state) =>
                CycleDetailScreen(cycleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/cycles/:id/items',
            name: RouteNames.cyclesItems,
            builder: (_, state) =>
                CycleItemsScreen(cycleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/cycles/:id/control-tests',
            name: RouteNames.cyclesControlTests,
            builder: (_, state) => CycleControlTestsScreen(
                cycleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/cycles/:id/attachments',
            name: RouteNames.cyclesAttachments,
            builder: (_, state) => CycleAttachmentsScreen(
                cycleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/cycles/:id/release',
            name: RouteNames.cyclesRelease,
            builder: (_, state) =>
                CycleReleaseScreen(cycleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/labels/:code',
            name: RouteNames.labelsDetail,
            builder: (_, state) =>
                LabelDetailScreen(code: state.pathParameters['code']!),
          ),
          GoRoute(
            path: '/app/labels/:code/blocked',
            name: RouteNames.labelsBlocked,
            builder: (_, state) =>
                LabelBlockedScreen(code: state.pathParameters['code']!),
          ),
          GoRoute(
            path: '/app/labels/:labelId/usage',
            name: RouteNames.labelsUsage,
            builder: (_, state) => LabelUsageFormScreen(
                labelId: state.pathParameters['labelId']!),
          ),
          GoRoute(
            path: Routes.team,
            builder: (_, __) => const TeamListScreen(),
          ),
          GoRoute(
            path: '/app/team/:id',
            builder: (_, state) =>
                TeamDetailScreen(memberId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: Routes.sites,
            builder: (_, __) => const SiteListScreen(),
          ),
          GoRoute(
            path: Routes.nonConformities,
            builder: (_, __) => const NonConformitiesScreen(),
          ),
          GoRoute(
            path: Routes.dataExports,
            builder: (_, __) => const DataExportRequestScreen(),
          ),
          GoRoute(
            path: Routes.audit,
            name: RouteNames.audit,
            builder: (_, __) => const AuditListScreen(),
          ),
          GoRoute(
            path: Routes.sync,
            name: RouteNames.sync,
            builder: (_, __) => const SyncQueueScreen(),
          ),
          GoRoute(
            path: Routes.about,
            name: RouteNames.about,
            builder: (_, __) => const AboutScreen(),
          ),
        ],
      ),
    ],
  );
}
DART_EOF

cat > lib/core/storage/session_store.dart << 'DART_EOF'
import 'dart:convert';

import 'secure_storage.dart';

class SessionStore {
  static const _userKey = 'steriymed.session.user';
  static const _tenantKey = 'steriymed.session.tenant';

  final SecureStorage _secure;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _tenant;

  SessionStore(this._secure);

  Map<String, dynamic>? get user => _user;
  Map<String, dynamic>? get tenant => _tenant;
  bool get hasSession => _user != null && _tenant != null;

  String? get role => _user?['role']?.toString();
  String? get userId => _user?['id']?.toString();
  String? get userName => _user?['name']?.toString();
  String? get userEmail => _user?['email']?.toString();
  String? get tenantName => _tenant?['name']?.toString();
  String? get tenantSlug => _tenant?['slug']?.toString();

  Future<void> load() async {
    final u = await _secure.read(_userKey);
    final t = await _secure.read(_tenantKey);
    if (u == null || t == null) return;
    _user = (jsonDecode(u) as Map).cast<String, dynamic>();
    _tenant = (jsonDecode(t) as Map).cast<String, dynamic>();
  }

  Future<void> set({
    required Map<String, dynamic> user,
    required Map<String, dynamic> tenant,
  }) async {
    _user = user;
    _tenant = tenant;
    await _secure.write(_userKey, jsonEncode(user));
    await _secure.write(_tenantKey, jsonEncode(tenant));
  }

  Future<void> clear() async {
    _user = null;
    _tenant = null;
    await _secure.delete(_userKey);
    await _secure.delete(_tenantKey);
  }
}
DART_EOF

cat > lib/core/storage/secure_storage.dart << 'DART_EOF'
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  Future<void> delete(String key) => _storage.delete(key: key);
  Future<void> clear() => _storage.deleteAll();
}
DART_EOF

cat > lib/core/storage/token_storage.dart << 'DART_EOF'
import 'secure_storage.dart';

class TokenStorage {
  static const _key = 'steriymed.bearer';
  final SecureStorage _secure;

  TokenStorage(this._secure);

  Future<String?> read() => _secure.read(_key);
  Future<void> save(String token) => _secure.write(_key, token);
  Future<void> clear() => _secure.delete(_key);
}
DART_EOF

cat > lib/bootstrap.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/crash/crash_reporter.dart';
import 'core/storage/session_store.dart';
import 'core/sync/sync_status_cubit.dart';
import 'di/di.dart';

Future<void> bootstrap(Widget Function() appBuilder) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await initDi();
  await getIt<SessionStore>().load();
  await getIt<CrashReporter>().init();
  await getIt<SyncStatusCubit>().start();
  runApp(appBuilder());
}
DART_EOF

cat > lib/di/storage_di.dart << 'DART_EOF'
import 'package:get_it/get_it.dart';

import '../core/storage/key_value_store.dart';
import '../core/storage/outbox/outbox_store.dart';
import '../core/storage/secure_storage.dart';
import '../core/storage/session_store.dart';
import '../core/storage/token_storage.dart';

Future<void> registerStorage(GetIt getIt) async {
  final secure = SecureStorage();
  getIt.registerSingleton<SecureStorage>(secure);
  getIt.registerSingleton<TokenStorage>(TokenStorage(secure));
  getIt.registerSingleton<SessionStore>(SessionStore(secure));

  final kv = await KeyValueStore.open('steriymed.kv');
  getIt.registerSingleton<KeyValueStore>(kv);

  final outbox = await OutboxStore.open();
  getIt.registerSingleton<OutboxStore>(outbox);
}
DART_EOF

cat > lib/di/router_di.dart << 'DART_EOF'
import 'package:get_it/get_it.dart';

import '../core/router/app_router.dart';
import '../core/storage/session_store.dart';
import '../core/storage/token_storage.dart';

Future<void> registerRouter(GetIt getIt) async {
  getIt.registerLazySingleton<AppRouter>(
    () => AppRouter(
      isAuthenticated: () => getIt<SessionStore>().hasSession,
      hasStoredToken: () async {
        final token = await getIt<TokenStorage>().read();
        return token != null && token.isNotEmpty;
      },
    ),
  );
}
DART_EOF

cat > lib/core/sync/connectivity_service.dart << 'DART_EOF'
import 'dart:async';

import '../network/network_info.dart';

class ConnectivityService {
  final NetworkInfo _networkInfo;
  final _controller = StreamController<bool>.broadcast();

  ConnectivityService(this._networkInfo) {
    _networkInfo.onStatusChange.listen(_controller.add);
  }

  Stream<bool> get onStatusChange => _controller.stream;
  Future<bool> get isConnected => _networkInfo.isConnected;
  void dispose() => _controller.close();
}
DART_EOF

cat > lib/core/sync/sync_status_cubit.dart << 'DART_EOF'
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../storage/outbox/outbox_store.dart';
import '../storage/outbox/sync_engine.dart';
import 'connectivity_service.dart';
import 'sync_status.dart';

class SyncStatusCubit extends Cubit<SyncStatus> {
  final OutboxStore _store;
  final SyncEngine _engine;
  final ConnectivityService _connectivity;
  StreamSubscription<bool>? _sub;

  SyncStatusCubit({
    required OutboxStore store,
    required SyncEngine engine,
    required ConnectivityService connectivity,
  })  : _store = store,
        _engine = engine,
        _connectivity = connectivity,
        super(const SyncStatus());

  Future<void> start() async {
    final online = await _connectivity.isConnected;
    _refresh(online: online);
    _sub = _connectivity.onStatusChange.listen((online) async {
      _refresh(online: online);
      if (online) {
        await _engine.flush();
        _refresh(online: true);
      }
    });
  }

  void _refresh({bool? online}) {
    emit(state.copyWith(
      online: online ?? state.online,
      pendingCount: _store.pendingCount,
      manualReviewCount: _store.manualReview().length,
    ));
  }

  Future<void> refreshNow() async => _refresh();

  @override
  Future<void> close() async {
    await _sub?.cancel();
    _connectivity.dispose();
    return super.close();
  }
}
DART_EOF

cat > lib/core/network/interceptors/idempotency_interceptor.dart << 'DART_EOF'
import 'package:dio/dio.dart';

import '../../utils/idempotency_key.dart';

class IdempotencyInterceptor extends Interceptor {
  static const _queuablePaths = <String>[
    '/auth/',
    '/labels/',
    '/stock-movements/',
    '/cycles/',
    '/tenants',
    '/invitations',
    '/non-conformities/',
  ];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method == 'POST' &&
        _isQueuable(options.path) &&
        !options.headers.containsKey('Idempotency-Key')) {
      options.headers['Idempotency-Key'] = generateIdempotencyKey();
    }
    handler.next(options);
  }

  bool _isQueuable(String path) => _queuablePaths.any(path.contains);
}
DART_EOF

cat > lib/features/auth/data/repositories/auth_repository.dart << 'DART_EOF'
import '../../../../core/storage/session_store.dart';
import '../../../../core/storage/token_storage.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepository {
  final AuthRemoteDatasource _remote;
  final TokenStorage _tokenStorage;
  final SessionStore _sessionStore;

  AuthRepository({
    required AuthRemoteDatasource remote,
    required TokenStorage tokenStorage,
    required SessionStore sessionStore,
  })  : _remote = remote,
        _tokenStorage = tokenStorage,
        _sessionStore = sessionStore;

  Future<void> login({
    required String tenantSlug,
    required String email,
    required String password,
  }) async {
    final res = await _remote.login(
      tenantSlug: tenantSlug,
      email: email,
      password: password,
    );
    await _tokenStorage.save(res.token);
    await _sessionStore.set(user: res.user.toJson(), tenant: res.tenant.toJson());
  }

  Future<void> register({
    required String tenantName,
    required String tenantSlug,
    required String ownerName,
    required String ownerEmail,
    required String password,
  }) async {
    final res = await _remote.register(
      tenantName: tenantName,
      tenantSlug: tenantSlug,
      ownerName: ownerName,
      ownerEmail: ownerEmail,
      password: password,
    );
    await _tokenStorage.save(res.token);
    await _sessionStore.set(user: res.user.toJson(), tenant: res.tenant.toJson());
  }

  Future<void> logout() async {
    try {
      await _remote.logout();
    } finally {
      await _tokenStorage.clear();
      await _sessionStore.clear();
    }
  }

  Future<void> logoutEverywhere() async {
    try {
      await _remote.logoutEverywhere();
    } finally {
      await _tokenStorage.clear();
      await _sessionStore.clear();
    }
  }

  Future<bool> restoreSession() async {
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) return false;
    try {
      final res = await _remote.me();
      await _sessionStore.set(
        user: res.user.toJson(),
        tenant: res.tenant.toJson(),
      );
      return true;
    } catch (_) {
      await _tokenStorage.clear();
      await _sessionStore.clear();
      return false;
    }
  }
}
DART_EOF

echo "   ✔ core layer written"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 2 — Dashboard
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Phase 2 — Dashboard"
mkdir -p lib/features/dashboard/data/models \
         lib/features/dashboard/data/datasources \
         lib/features/dashboard/data/repositories \
         lib/features/dashboard/presentation/cubit \
         lib/features/dashboard/presentation/screens

cat > lib/features/dashboard/data/models/dashboard_data.dart << 'DART_EOF'
class DashboardKpi {
  final String id;
  final String label;
  final int value;
  final String route;
  const DashboardKpi({
    required this.id,
    required this.label,
    required this.value,
    required this.route,
  });
}

class DashboardAttentionItem {
  final String id;
  final String label;
  final String severity;
  final String route;
  const DashboardAttentionItem({
    required this.id,
    required this.label,
    required this.severity,
    required this.route,
  });
}

class DashboardTodayCycle {
  final String id;
  final String number;
  final String deviceName;
  final String status;
  const DashboardTodayCycle({
    required this.id,
    required this.number,
    required this.deviceName,
    required this.status,
  });
}

class DashboardRecentProcedure {
  final String id;
  final String label;
  final String patientReference;
  final String usedAt;
  const DashboardRecentProcedure({
    required this.id,
    required this.label,
    required this.patientReference,
    required this.usedAt,
  });
}

class DashboardData {
  final String greeting;
  final String userName;
  final List<DashboardKpi> kpis;
  final List<DashboardAttentionItem> attention;
  final List<DashboardTodayCycle> todayCycles;
  final List<DashboardRecentProcedure> recentProcedures;

  const DashboardData({
    required this.greeting,
    required this.userName,
    required this.kpis,
    required this.attention,
    required this.todayCycles,
    required this.recentProcedures,
  });

  DashboardData copyWith({String? userName}) => DashboardData(
        greeting: greeting,
        userName: userName ?? this.userName,
        kpis: kpis,
        attention: attention,
        todayCycles: todayCycles,
        recentProcedures: recentProcedures,
      );
}
DART_EOF

cat > lib/features/dashboard/data/datasources/dashboard_remote_datasource.dart << 'DART_EOF'
import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../models/dashboard_data.dart';

class DashboardRemoteDatasource {
  final Dio _dio;
  const DashboardRemoteDatasource(this._dio);

  Future<DashboardData> fetch() async {
    final results = await Future.wait<Object?>([
      _safeGet(ApiEndpoints.cycles, {'per_page': 50}),
      _safeGet(ApiEndpoints.alerts, {'resolved': false, 'per_page': 50}),
      _safeGet(ApiEndpoints.auditEvents, {'per_page': 20}),
    ]);

    final cycles = _list(results[0]);
    final alerts = _list(results[1]);
    final audit = _list(results[2]);

    final now = DateTime.now();
    final activeCycles = cycles
        .where((c) => c['status'] != 'released' && c['status'] != 'rejected')
        .length;

    final todayCycles = cycles.where((c) {
      final t = DateTime.tryParse(c['created_at']?.toString() ?? '');
      return t != null &&
          t.year == now.year &&
          t.month == now.month &&
          t.day == now.day;
    }).toList();

    return DashboardData(
      greeting: _greeting(now),
      userName: '',
      kpis: [
        DashboardKpi(
          id: 'active_cycles',
          label: 'Cycles en cours',
          value: activeCycles,
          route: '/app/cycles',
        ),
        DashboardKpi(
          id: 'pending_alerts',
          label: 'Alertes actives',
          value: alerts.length,
          route: '/app/alerts',
        ),
        DashboardKpi(
          id: 'today_cycles',
          label: 'Cycles du jour',
          value: todayCycles.length,
          route: '/app/cycles',
        ),
        DashboardKpi(
          id: 'audit_events',
          label: 'Événements récents',
          value: audit.length,
          route: '/app/audit',
        ),
      ],
      attention: alerts.take(3).map((a) {
        return DashboardAttentionItem(
          id: a['id']?.toString() ?? '',
          label: a['message']?.toString() ?? 'Alerte',
          severity: a['severity']?.toString() ?? 'info',
          route: '/app/alerts',
        );
      }).toList(),
      todayCycles: todayCycles.take(5).map((c) {
        return DashboardTodayCycle(
          id: c['id']?.toString() ?? '',
          number: c['number']?.toString() ?? '',
          deviceName: c['device_name']?.toString() ?? '',
          status: c['status']?.toString() ?? '',
        );
      }).toList(),
      recentProcedures: audit.take(5).map((e) {
        return DashboardRecentProcedure(
          id: e['id']?.toString() ?? '',
          label: e['action']?.toString() ?? '',
          patientReference: e['subject_id']?.toString() ?? '',
          usedAt: e['occurred_at']?.toString() ?? '',
        );
      }).toList(),
    );
  }

  Future<Object?> _safeGet(String path, Map<String, dynamic> query) async {
    try {
      final res = await _dio.get(path, queryParameters: query);
      return res.data;
    } on DioException {
      return null;
    }
  }

  List<Map<String, dynamic>> _list(Object? data) {
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    return const [];
  }

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }
}
DART_EOF

cat > lib/features/dashboard/data/repositories/dashboard_repository.dart << 'DART_EOF'
import '../datasources/dashboard_remote_datasource.dart';
import '../models/dashboard_data.dart';

class DashboardRepository {
  final DashboardRemoteDatasource _remote;
  DashboardRepository(this._remote);
  Future<DashboardData> fetch() => _remote.fetch();
}
DART_EOF

cat > lib/features/dashboard/presentation/cubit/dashboard_cubit.dart << 'DART_EOF'
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/session_store.dart';
import '../../data/repositories/dashboard_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository _repository;
  final SessionStore _session;

  DashboardCubit(this._repository, this._session)
      : super(const DashboardInitial());

  Future<void> load() async {
    emit(const DashboardLoading());
    try {
      final data = await _repository.fetch();
      emit(DashboardLoaded(data.copyWith(userName: _session.userName ?? '')));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }
}
DART_EOF

cat > lib/features/dashboard/presentation/screens/dashboard_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/cards/kpi_card.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../../shell/presentation/widgets/profile_menu.dart';
import '../../data/models/dashboard_data.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DashboardCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionStore>();
    final name = session.userName ?? 'Utilisateur';
    final email = session.userEmail ?? '';
    final role = session.role ?? 'staff';
    final isOwner = role == 'owner' || role == 'admin';

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<DashboardCubit>().load(),
          child: BlocBuilder<DashboardCubit, DashboardState>(
            builder: (context, state) {
              if (state is DashboardLoading) {
                return const LoadingView(
                  message: 'Chargement du tableau de bord...',
                );
              }
              if (state is DashboardError) {
                return ErrorView(
                  message: state.message,
                  onRetry: () => context.read<DashboardCubit>().load(),
                );
              }

              final data = state is DashboardLoaded ? state.data : null;

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _Header(
                    name: name,
                    email: email,
                    role: role,
                    greeting: data?.greeting ?? 'Bonjour',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _KpiGrid(data: data),
                  const SizedBox(height: AppSpacing.lg),
                  if (data != null && data.attention.isNotEmpty) ...[
                    const SectionHeader(title: 'Nécessite votre attention'),
                    for (final item in data.attention)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _AttentionTile(item: item),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  SectionHeader(
                    title: isOwner
                        ? 'Centre de gouvernance'
                        : 'Accès rapides',
                  ),
                  _GovernanceMenu(isOwner: isOwner),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final String greeting;

  const _Header({
    required this.name,
    required this.email,
    required this.role,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $name',
                style: AppTypography.pageTitle.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 2),
              const Text(
                'Voici la situation du cabinet',
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
        ProfileMenu(displayName: name, email: email, role: role),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final DashboardData? data;
  const _KpiGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final kpis = data?.kpis ?? const <DashboardKpi>[];
    if (kpis.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.55,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, i) {
        final k = kpis[i];
        return KpiCard(
          label: k.label,
          value: k.value.toString(),
          icon: _iconFor(k.id),
          onTap: k.route.isEmpty ? null : () => context.go(k.route),
        );
      },
    );
  }

  IconData _iconFor(String id) {
    switch (id) {
      case 'active_cycles':
        return Icons.autorenew;
      case 'pending_alerts':
        return Icons.warning_amber_outlined;
      case 'today_cycles':
        return Icons.today_outlined;
      case 'audit_events':
        return Icons.fact_check_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}

class _AttentionTile extends StatelessWidget {
  final DashboardAttentionItem item;
  const _AttentionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (item.severity) {
      'critical' => (
          AppColors.dangerLight,
          AppColors.danger,
          Icons.error_outline
        ),
      'warning' => (
          AppColors.warningLight,
          AppColors.warning,
          Icons.warning_amber_outlined
        ),
      _ => (AppColors.infoLight, AppColors.info, Icons.info_outline),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.route),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.label,
                  style: AppTypography.bodyStrong.copyWith(color: fg),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GovernanceMenu extends StatelessWidget {
  final bool isOwner;
  const _GovernanceMenu({required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final items = <_MenuItem>[
      const _MenuItem(
        'Cycles de stérilisation',
        'Suivi complet des autoclaves',
        Icons.autorenew,
        Routes.cycles,
      ),
      const _MenuItem(
        'Stock & Catalogue',
        'Produits, lots, mouvements et inventaire',
        Icons.inventory_2_outlined,
        Routes.stock,
      ),
      const _MenuItem(
        'Gestion des patients',
        'Fiches patients et historiques',
        Icons.people_outline,
        Routes.patients,
      ),
      const _MenuItem(
        'Non-Conformités & Rappels',
        'Registre des incidents et quarantaines',
        Icons.warning_amber_outlined,
        Routes.nonConformities,
      ),
      const _MenuItem(
        'Journal d\'Audit',
        'Traces immuables et événements cliniques',
        Icons.verified_user_outlined,
        Routes.audit,
      ),
      if (isOwner)
        const _MenuItem(
          'Équipe & Droits',
          'Comptes du personnel et permissions',
          Icons.person_add_alt_outlined,
          Routes.team,
        ),
      if (isOwner)
        const _MenuItem(
          'Sites & Salles',
          'Fauteuils, zones stériles et stockage',
          Icons.meeting_room_outlined,
          Routes.sites,
        ),
      const _MenuItem(
        'Export Données',
        'Portabilité RGPD / ARS',
        Icons.download_outlined,
        Routes.dataExports,
      ),
    ];

    return Column(
      children: [
        for (final item in items) ...[
          _ActionRow(item: item),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final _MenuItem item;
  const _ActionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.route),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child:
                    Icon(item.icon, size: 18, color: AppColors.brandPrimary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: AppTypography.bodyStrong),
                    const SizedBox(height: 2),
                    Text(item.subtitle, style: AppTypography.caption),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  const _MenuItem(this.title, this.subtitle, this.icon, this.route);
}
DART_EOF

echo "   ✔ dashboard written"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 3 — Scanner + Labels + Patient picker
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Phase 3 — Scanner + Labels + Patient picker"
mkdir -p lib/features/scanner/presentation/bloc \
         lib/features/scanner/presentation/screens \
         lib/features/labels/presentation/screens \
         lib/features/patients/presentation/widgets

cat > lib/features/scanner/presentation/bloc/scanner_bloc.dart << 'DART_EOF'
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../labels/data/models/label_scan_result.dart';
import '../../../labels/data/repositories/label_repository.dart';

part 'scanner_event.dart';
part 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final LabelRepository _labels;
  Timer? _cooldownTimer;

  ScannerBloc(this._labels) : super(const ScannerState()) {
    on<ScanDetected>(_onScan);
    on<ScannerCooldownExpired>(_onCooldownExpired);
    on<TorchToggled>(_onTorch);
    on<ScannerReset>(_onReset);
  }

  Future<void> _onScan(ScanDetected e, Emitter<ScannerState> emit) async {
    if (state.status == ScannerStatus.cooling ||
        state.status == ScannerStatus.resolving) {
      return;
    }
    emit(state.copyWith(
      status: ScannerStatus.resolving,
      lastCode: e.rawValue,
      error: null,
    ));
    try {
      final result = await _labels.getByCode(e.rawValue);
      emit(state.copyWith(status: ScannerStatus.resolved, result: result));
      _startCooldown();
    } on ApiException catch (ex) {
      emit(state.copyWith(status: ScannerStatus.error, error: ex.message));
      _startCooldown();
    } catch (ex) {
      emit(state.copyWith(
        status: ScannerStatus.error,
        error: 'Erreur de lecture : ${ex.toString()}',
      ));
      _startCooldown();
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(AppConfig.scanCooldown, () {
      add(const ScannerCooldownExpired());
    });
  }

  void _onCooldownExpired(ScannerCooldownExpired e, Emitter<ScannerState> emit) {
    if (state.status == ScannerStatus.resolved ||
        state.status == ScannerStatus.error) {
      emit(state.copyWith(
        status: ScannerStatus.scanning,
        clearResult: true,
      ));
    }
  }

  void _onTorch(TorchToggled e, Emitter<ScannerState> emit) {
    emit(state.copyWith(torchOn: !state.torchOn));
  }

  void _onReset(ScannerReset e, Emitter<ScannerState> emit) {
    _cooldownTimer?.cancel();
    emit(const ScannerState());
  }

  @override
  Future<void> close() {
    _cooldownTimer?.cancel();
    return super.close();
  }
}
DART_EOF

cat > lib/features/scanner/presentation/bloc/scanner_state.dart << 'DART_EOF'
part of 'scanner_bloc.dart';

enum ScannerStatus { initial, scanning, cooling, resolving, resolved, error }

class ScannerState extends Equatable {
  final ScannerStatus status;
  final String? lastCode;
  final LabelScanResult? result;
  final String? error;
  final bool torchOn;

  const ScannerState({
    this.status = ScannerStatus.initial,
    this.lastCode,
    this.result,
    this.error,
    this.torchOn = false,
  });

  ScannerState copyWith({
    ScannerStatus? status,
    String? lastCode,
    LabelScanResult? result,
    String? error,
    bool? torchOn,
    bool clearResult = false,
  }) {
    return ScannerState(
      status: status ?? this.status,
      lastCode: lastCode ?? this.lastCode,
      result: clearResult ? null : (result ?? this.result),
      error: error ?? this.error,
      torchOn: torchOn ?? this.torchOn,
    );
  }

  @override
  List<Object?> get props => [status, lastCode, result, error, torchOn];
}
DART_EOF

cat > lib/features/scanner/presentation/bloc/scanner_event.dart << 'DART_EOF'
part of 'scanner_bloc.dart';

abstract class ScannerEvent extends Equatable {
  const ScannerEvent();
  @override
  List<Object?> get props => [];
}

class ScanDetected extends ScannerEvent {
  final String rawValue;
  const ScanDetected(this.rawValue);
  @override
  List<Object> get props => [rawValue];
}

class ScannerCooldownExpired extends ScannerEvent {
  const ScannerCooldownExpired();
}

class TorchToggled extends ScannerEvent {
  const TorchToggled();
}

class ScannerReset extends ScannerEvent {
  const ScannerReset();
}
DART_EOF

cat > lib/features/scanner/presentation/screens/scanner_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../bloc/scanner_bloc.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ScannerBloc(ctx.read())..add(const ScannerReset()),
      child: const _ScannerView(),
    );
  }
}

class _ScannerView extends StatefulWidget {
  const _ScannerView();

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView> {
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    context.read<ScannerBloc>().add(ScanDetected(raw));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scanner une étiquette'),
        actions: [
          BlocBuilder<ScannerBloc, ScannerState>(
            buildWhen: (p, c) => p.torchOn != c.torchOn,
            builder: (context, state) => IconButton(
              icon: Icon(state.torchOn ? Icons.flash_on : Icons.flash_off),
              tooltip: state.torchOn ? 'Éteindre la lampe' : 'Allumer la lampe',
              onPressed: () {
                _controller.toggleTorch();
                context.read<ScannerBloc>().add(const TorchToggled());
              },
            ),
          ),
        ],
      ),
      body: BlocListener<ScannerBloc, ScannerState>(
        listenWhen: (p, c) =>
            p.status != c.status || p.lastCode != c.lastCode,
        listener: (context, state) {
          if (state.status == ScannerStatus.resolved && state.result != null) {
            final r = state.result!;
            if (r.isBlocked) {
              context.go(Routes.labelsBlocked(r.code));
            } else if (r.label != null) {
              context.go(Routes.labelsDetail(r.code));
            }
          }
          if (state.status == ScannerStatus.error && state.error != null) {
            AppSnackbar.show(context, state.error!, kind: SnackKind.error);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(controller: _controller, onDetect: _onDetect),
            const _ScanFrameOverlay(),
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.xxl,
              child: BlocBuilder<ScannerBloc, ScannerState>(
                builder: (context, state) {
                  final isResolving =
                      state.status == ScannerStatus.resolving;
                  return Column(
                    children: [
                      if (isResolving)
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Alignez le QR code dans le cadre',
                        style: AppTypography.bodyStrong.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanFrameOverlay extends StatelessWidget {
  const _ScanFrameOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 3),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}
DART_EOF

cat > lib/features/labels/presentation/screens/label_detail_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../data/models/label_data.dart';
import '../../data/models/label_scan_result.dart';
import '../bloc/label_detail_bloc.dart';

class LabelDetailScreen extends StatelessWidget {
  final String code;
  const LabelDetailScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => LabelDetailBloc(ctx.read())..add(LoadLabel(code)),
      child: const _LabelDetailView(),
    );
  }
}

class _LabelDetailView extends StatelessWidget {
  const _LabelDetailView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Étiquette')),
      body: BlocBuilder<LabelDetailBloc, LabelDetailState>(
        builder: (context, state) {
          if (state.status == LabelDetailStatus.loading) {
            return const LoadingView(message: 'Chargement de l\'étiquette...');
          }
          if (state.status == LabelDetailStatus.failure) {
            return ErrorView(message: state.error ?? 'Étiquette introuvable.');
          }

          final result = state.result;
          if (result == null) return const SizedBox.shrink();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _StatusHeader(result: result),
              const SizedBox(height: AppSpacing.md),
              if (result.label != null) _InfoSection(label: result.label!),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Enregistrer utilisation',
                icon: Icons.assignment_turned_in_outlined,
                onPressed: result.label == null || result.isBlocked
                    ? null
                    : () => context.go(Routes.labelsUsage(result.label!.id)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final LabelScanResult result;
  const _StatusHeader({required this.result});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    String label;
    switch (result.status) {
      case LabelScanStatus.valid:
        bg = AppColors.successLight;
        fg = AppColors.success;
        icon = Icons.verified_outlined;
        label = 'Étiquette valide';
        break;
      case LabelScanStatus.expired:
        bg = AppColors.dangerLight;
        fg = AppColors.danger;
        icon = Icons.timer_off_outlined;
        label = 'Étiquette expirée';
        break;
      case LabelScanStatus.recalled:
        bg = AppColors.dangerLight;
        fg = AppColors.danger;
        icon = Icons.report_gmailerrorred_outlined;
        label = 'Étiquette rappelée';
        break;
      case LabelScanStatus.unknown:
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        icon = Icons.help_outline;
        label = 'Statut inconnu';
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: fg),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: AppTypography.sectionTitle.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final LabelData label;
  const _InfoSection({required this.label});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          _row(Icons.qr_code_2, 'Code', label.code),
          if (label.productName != null)
            _row(Icons.inventory_2_outlined, 'Produit', label.productName!),
          if (label.batchNumber != null)
            _row(Icons.numbers, 'Lot', label.batchNumber!),
          if (label.cycleNumber != null)
            _row(Icons.autorenew, 'Cycle', label.cycleNumber!),
          if (label.deviceName != null)
            _row(Icons.precision_manufacturing_outlined, 'Appareil',
                label.deviceName!),
          if (label.sterilizedAt != null)
            _row(Icons.event_available_outlined, 'Stérilisé le',
                dateFmt.format(label.sterilizedAt!)),
          if (label.expiresAt != null)
            _row(Icons.event_busy_outlined, 'Expire le',
                dateFmt.format(label.expiresAt!)),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.label)),
          Text(value, style: AppTypography.bodyStrong),
        ],
      ),
    );
  }
}
DART_EOF

cat > lib/features/labels/presentation/screens/label_blocked_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../bloc/label_detail_bloc.dart';

class LabelBlockedScreen extends StatelessWidget {
  final String code;
  const LabelBlockedScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => LabelDetailBloc(ctx.read())..add(LoadLabel(code)),
      child: const _BlockedView(),
    );
  }
}

class _BlockedView extends StatelessWidget {
  const _BlockedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Étiquette bloquée'),
        backgroundColor: AppColors.dangerLight,
        foregroundColor: AppColors.danger,
      ),
      body: BlocBuilder<LabelDetailBloc, LabelDetailState>(
        builder: (context, state) {
          if (state.status == LabelDetailStatus.failure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  state.error ?? 'Impossible de charger l\'étiquette.',
                  style: AppTypography.body,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (state.status != LabelDetailStatus.success ||
              state.result == null) {
            return const LoadingView();
          }

          final r = state.result!;
          final isExpired = r.status.name == 'expired';
          final isRecalled = r.status.name == 'recalled';

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isExpired
                            ? Icons.timer_off_outlined
                            : isRecalled
                                ? Icons.report_gmailerrorred_outlined
                                : Icons.block,
                        size: 64,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        isExpired
                            ? 'Étiquette expirée'
                            : isRecalled
                                ? 'Étiquette rappelée'
                                : 'Étiquette bloquée',
                        style: AppTypography.sectionTitle
                            .copyWith(color: AppColors.danger),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        r.reason ??
                            'Cette étiquette ne peut pas être utilisée. '
                                'Contactez le responsable de la stérilisation.',
                        style: AppTypography.body,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Text(
                    'Retournez à l\'écran précédent pour scanner une autre étiquette.',
                    style: AppTypography.caption,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
DART_EOF

cat > lib/features/labels/presentation/screens/label_usage_form_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../patients/data/models/patient_data.dart';
import '../../../patients/presentation/widgets/patient_picker_sheet.dart';
import '../../data/repositories/label_usage_repository.dart';

class LabelUsageFormScreen extends StatefulWidget {
  final String labelId;
  const LabelUsageFormScreen({super.key, required this.labelId});

  @override
  State<LabelUsageFormScreen> createState() => _LabelUsageFormScreenState();
}

class _LabelUsageFormScreenState extends State<LabelUsageFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _procedureCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  PatientData? _patient;
  bool _submitting = false;

  @override
  void dispose() {
    _procedureCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPatient() async {
    final picked = await PatientPickerSheet.show(context);
    if (picked != null && mounted) {
      setState(() => _patient = picked);
    }
  }

  Future<void> _submit() async {
    if (_patient == null) {
      AppSnackbar.show(context, 'Sélectionnez un patient.',
          kind: SnackKind.warning);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final practitionerId = getIt<SessionStore>().userId ?? '';
    if (practitionerId.isEmpty) {
      AppSnackbar.show(context, 'Session invalide.', kind: SnackKind.error);
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<LabelUsageRepository>().recordUsage(
            labelId: widget.labelId,
            patientId: _patient!.id,
            practitionerId: practitionerId,
            procedure: _procedureCtrl.text.trim(),
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          );
      if (!mounted) return;
      AppSnackbar.show(context, 'Utilisation enregistrée.',
          kind: SnackKind.success);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Enregistrer utilisation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.brandPrimaryLight,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_2, color: AppColors.brandPrimary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Étiquette', style: AppTypography.label),
                        const SizedBox(height: 2),
                        Text(
                          widget.labelId,
                          style: AppTypography.bodyStrong,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionLabel('PATIENT'),
            InkWell(
              onTap: _pickPatient,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InputDecorator(
                decoration: const InputDecoration(
                  hintText: 'Sélectionner un patient',
                  suffixIcon: Icon(Icons.person_search_outlined),
                ),
                child: Text(
                  _patient?.fullName ?? 'Sélectionner un patient',
                  style: AppTypography.body.copyWith(
                    color: _patient == null
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _SectionLabel('ACTE / PROCÉDURE'),
            AppTextField(
              label: 'Procédure',
              hint: 'ex. Détartrage, Pose couronne...',
              controller: _procedureCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextArea(
              label: 'Notes (optionnel)',
              controller: _notesCtrl,
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Enregistrer',
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          letterSpacing: 0.6,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
DART_EOF

cat > lib/features/patients/presentation/widgets/patient_picker_sheet.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../data/models/patient_data.dart';
import '../../data/repositories/patient_repository.dart';
import '../bloc/patient_search_bloc.dart';
import 'patient_tile.dart';

class PatientPickerSheet extends StatelessWidget {
  const PatientPickerSheet({super.key});

  static Future<PatientData?> show(BuildContext context) {
    return showModalBottomSheet<PatientData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => BlocProvider(
        create: (_) => PatientSearchBloc(getIt<PatientRepository>()),
        child: const PatientPickerSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderMedium,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sélectionner un patient',
                      style: AppTypography.sectionTitle,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: AppSearchField(
                hint: 'Rechercher par nom, prénom...',
                controller: controller,
                autofocus: true,
                onChanged: (q) => context
                    .read<PatientSearchBloc>()
                    .add(PatientSearchQueryChanged(q)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: BlocBuilder<PatientSearchBloc, PatientSearchState>(
                builder: (context, state) {
                  if (state.status == PatientSearchStatus.loading &&
                      state.results.isEmpty) {
                    return const LoadingView();
                  }
                  if (state.status == PatientSearchStatus.failure) {
                    return ErrorView(message: state.error ?? 'Erreur');
                  }
                  if (state.status == PatientSearchStatus.success &&
                      state.results.isEmpty) {
                    return const EmptyView(
                      title: 'Aucun patient',
                      message: 'Essayez une autre recherche.',
                      icon: Icons.person_search_outlined,
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: state.results.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final p = state.results[i];
                      return PatientTile(
                        patient: p,
                        onTap: () => Navigator.of(context).pop(p),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
DART_EOF

echo "   ✔ scanner/labels/patients written"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 4 — Stock
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Phase 4 — Stock"
mkdir -p lib/features/stock/data/models \
         lib/features/stock/data/datasources \
         lib/features/stock/data/repositories \
         lib/features/stock/presentation/bloc \
         lib/features/stock/presentation/cubit \
         lib/features/stock/presentation/screens \
         lib/features/stock/presentation/widgets

cat > lib/features/stock/data/models/stock_level_data.dart << 'DART_EOF'
import 'package:equatable/equatable.dart';

class StockLevelData extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final String reference;
  final String unit;
  final String locationId;
  final String locationName;
  final int qty;
  final int minThreshold;
  final String? batchId;
  final String? batchNumber;
  final DateTime? expiryDate;
  final bool isLow;
  final bool isExpired;
  final bool isNearExpiry;

  const StockLevelData({
    required this.id,
    required this.productId,
    required this.productName,
    required this.reference,
    required this.unit,
    required this.locationId,
    required this.locationName,
    required this.qty,
    required this.minThreshold,
    this.batchId,
    this.batchNumber,
    this.expiryDate,
    this.isLow = false,
    this.isExpired = false,
    this.isNearExpiry = false,
  });

  factory StockLevelData.fromJson(Map<String, dynamic> json) {
    final qty = (json['qty'] as num?)?.toInt() ?? 0;
    final min = (json['min_threshold'] as num?)?.toInt() ?? 0;
    final expiresAt =
        DateTime.tryParse(json['expiry_date']?.toString() ?? '');
    bool expired = false;
    bool near = false;
    if (expiresAt != null) {
      final days = expiresAt.difference(DateTime.now()).inDays;
      expired = days < 0;
      near = !expired && days <= 30;
    }
    return StockLevelData(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'u',
      locationId: json['location_id']?.toString() ?? '',
      locationName: json['location_name']?.toString() ?? '',
      qty: qty,
      minThreshold: min,
      batchId: json['batch_id']?.toString(),
      batchNumber: json['batch_number']?.toString(),
      expiryDate: expiresAt,
      isLow: min > 0 && qty <= min,
      isExpired: expired,
      isNearExpiry: near,
    );
  }

  @override
  List<Object?> get props => [id, productId, locationId, batchId, qty];
}
DART_EOF

cat > lib/features/stock/data/models/stock_movement_data.dart << 'DART_EOF'
import 'package:equatable/equatable.dart';

class StockMovementData extends Equatable {
  final String id;
  final String kind;
  final String batchId;
  final String locationId;
  final int qty;
  final String? reason;
  final DateTime createdAt;

  const StockMovementData({
    required this.id,
    required this.kind,
    required this.batchId,
    required this.locationId,
    required this.qty,
    this.reason,
    required this.createdAt,
  });

  factory StockMovementData.fromJson(Map<String, dynamic> json) =>
      StockMovementData(
        id: json['id']?.toString() ?? '',
        kind: json['kind']?.toString() ?? '',
        batchId: json['batch_id']?.toString() ?? '',
        locationId: json['location_id']?.toString() ?? '',
        qty: (json['qty'] as num?)?.toInt() ?? 0,
        reason: json['reason']?.toString(),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  @override
  List<Object?> get props => [id, kind, batchId, locationId, qty, createdAt];
}
DART_EOF

cat > lib/features/stock/data/datasources/stock_remote_datasource.dart << 'DART_EOF'
import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/stock_level_data.dart';
import '../models/stock_movement_data.dart';

class StockRemoteDatasource {
  final Dio _dio;
  StockRemoteDatasource(this._dio);

  Future<List<StockLevelData>> listLevels({String? search}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.stockLevels,
        queryParameters: {
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          'per_page': 100,
        },
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => StockLevelData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<StockMovementData> issue({
    required String batchId,
    required String locationId,
    required int qty,
    String? reason,
  }) =>
      _postMovement(ApiEndpoints.stockIssue, {
        'batch_id': batchId,
        'location_id': locationId,
        'qty': qty,
        if (reason != null && reason.trim().isNotEmpty)
          'reason': reason.trim(),
      });

  Future<StockMovementData> adjust({
    required String batchId,
    required String locationId,
    required int qty,
    required String reason,
  }) =>
      _postMovement(ApiEndpoints.stockAdjust, {
        'batch_id': batchId,
        'location_id': locationId,
        'qty': qty,
        'reason': reason.trim(),
      });

  Future<StockMovementData> transfer({
    required String batchId,
    required String fromLocationId,
    required String toLocationId,
    required int qty,
    String? reason,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.stockTransfer,
        data: {
          'batch_id': batchId,
          'from_location_id': fromLocationId,
          'to_location_id': toLocationId,
          'qty': qty,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      final raw = res.data;
      if (raw is! Map) {
        throw const FormatException('Réponse de transfert invalide.');
      }
      final debit = raw['debit'];
      if (debit is! Map) {
        throw const FormatException('Réponse de transfert invalide.');
      }
      return StockMovementData.fromJson(debit.cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<StockMovementData> _postMovement(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _dio.post(
        path,
        data: payload,
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
      final raw = res.data;
      if (raw is! Map) throw const FormatException('Réponse invalide.');
      return StockMovementData.fromJson(raw.cast<String, dynamic>());
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
DART_EOF

cat > lib/features/stock/data/repositories/stock_repository.dart << 'DART_EOF'
import '../datasources/stock_remote_datasource.dart';
import '../models/stock_level_data.dart';
import '../models/stock_movement_data.dart';

class StockRepository {
  final StockRemoteDatasource _remote;
  StockRepository(this._remote);

  Future<List<StockLevelData>> listLevels({String? search}) =>
      _remote.listLevels(search: search);

  Future<StockMovementData> issue({
    required String batchId,
    required String locationId,
    required int qty,
    String? reason,
  }) =>
      _remote.issue(
        batchId: batchId,
        locationId: locationId,
        qty: qty,
        reason: reason,
      );

  Future<StockMovementData> adjust({
    required String batchId,
    required String locationId,
    required int qty,
    required String reason,
  }) =>
      _remote.adjust(
        batchId: batchId,
        locationId: locationId,
        qty: qty,
        reason: reason,
      );

  Future<StockMovementData> transfer({
    required String batchId,
    required String fromLocationId,
    required String toLocationId,
    required int qty,
    String? reason,
  }) =>
      _remote.transfer(
        batchId: batchId,
        fromLocationId: fromLocationId,
        toLocationId: toLocationId,
        qty: qty,
        reason: reason,
      );
}
DART_EOF

cat > lib/features/stock/presentation/cubit/stock_action_cubit.dart << 'DART_EOF'
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/repositories/stock_repository.dart';

part 'stock_action_state.dart';

class StockActionCubit extends Cubit<StockActionState> {
  final StockRepository _repository;

  StockActionCubit(this._repository) : super(const StockActionState());

  Future<bool> issue({
    required String batchId,
    required String locationId,
    required int qty,
    String? reason,
  }) =>
      _run(() => _repository.issue(
            batchId: batchId,
            locationId: locationId,
            qty: qty,
            reason: reason,
          ));

  Future<bool> adjust({
    required String batchId,
    required String locationId,
    required int qty,
    required String reason,
  }) =>
      _run(() => _repository.adjust(
            batchId: batchId,
            locationId: locationId,
            qty: qty,
            reason: reason,
          ));

  Future<bool> transfer({
    required String batchId,
    required String fromLocationId,
    required String toLocationId,
    required int qty,
    String? reason,
  }) =>
      _run(() => _repository.transfer(
            batchId: batchId,
            fromLocationId: fromLocationId,
            toLocationId: toLocationId,
            qty: qty,
            reason: reason,
          ));

  Future<bool> _run(Future<void> Function() op) async {
    emit(const StockActionState(status: StockActionStatus.loading));
    try {
      await op();
      emit(const StockActionState(status: StockActionStatus.success));
      return true;
    } on ApiException catch (e) {
      emit(StockActionState(
        status: StockActionStatus.failure,
        error: e.message,
      ));
      return false;
    }
  }
}
DART_EOF

cat > lib/features/stock/presentation/cubit/stock_action_state.dart << 'DART_EOF'
part of 'stock_action_cubit.dart';

enum StockActionStatus { idle, loading, success, failure }

class StockActionState extends Equatable {
  final StockActionStatus status;
  final String? error;

  const StockActionState({
    this.status = StockActionStatus.idle,
    this.error,
  });

  @override
  List<Object?> get props => [status, error];
}
DART_EOF

cat > lib/features/stock/presentation/bloc/stock_level_list_bloc.dart << 'DART_EOF'
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/stock_level_data.dart';
import '../../data/repositories/stock_repository.dart';

part 'stock_level_list_event.dart';
part 'stock_level_list_state.dart';

class StockLevelListBloc
    extends Bloc<StockLevelListEvent, StockLevelListState> {
  final StockRepository _repository;

  StockLevelListBloc(this._repository) : super(const StockLevelListState()) {
    on<LoadStockLevels>(_onLoad);
    on<RefreshStockLevels>(_onRefresh);
    on<SearchStockLevels>(_onSearch);
  }

  Future<void> _onLoad(
    LoadStockLevels event,
    Emitter<StockLevelListState> emit,
  ) async {
    emit(state.copyWith(status: StockLevelStatus.loading, error: null));
    try {
      final levels = await _repository.listLevels();
      emit(state.copyWith(
        status: StockLevelStatus.success,
        levels: levels,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: StockLevelStatus.failure,
        error: e.message,
      ));
    }
  }

  Future<void> _onRefresh(
    RefreshStockLevels event,
    Emitter<StockLevelListState> emit,
  ) async {
    try {
      final levels = await _repository.listLevels(search: state.query);
      emit(state.copyWith(status: StockLevelStatus.success, levels: levels));
    } on ApiException catch (e) {
      emit(state.copyWith(status: StockLevelStatus.failure, error: e.message));
    }
  }

  Future<void> _onSearch(
    SearchStockLevels event,
    Emitter<StockLevelListState> emit,
  ) async {
    emit(state.copyWith(query: event.query));
    try {
      final levels = await _repository.listLevels(search: event.query);
      emit(state.copyWith(status: StockLevelStatus.success, levels: levels));
    } on ApiException catch (e) {
      emit(state.copyWith(status: StockLevelStatus.failure, error: e.message));
    }
  }
}
DART_EOF

cat > lib/features/stock/presentation/bloc/stock_level_list_event.dart << 'DART_EOF'
part of 'stock_level_list_bloc.dart';

abstract class StockLevelListEvent extends Equatable {
  const StockLevelListEvent();
  @override
  List<Object?> get props => [];
}

class LoadStockLevels extends StockLevelListEvent {
  const LoadStockLevels();
}

class RefreshStockLevels extends StockLevelListEvent {
  const RefreshStockLevels();
}

class SearchStockLevels extends StockLevelListEvent {
  final String query;
  const SearchStockLevels(this.query);
  @override
  List<Object?> get props => [query];
}
DART_EOF

cat > lib/features/stock/presentation/bloc/stock_level_list_state.dart << 'DART_EOF'
part of 'stock_level_list_bloc.dart';

enum StockLevelStatus { initial, loading, success, failure }

class StockLevelListState extends Equatable {
  final StockLevelStatus status;
  final List<StockLevelData> levels;
  final String query;
  final String? error;

  const StockLevelListState({
    this.status = StockLevelStatus.initial,
    this.levels = const [],
    this.query = '',
    this.error,
  });

  int get totalRefs => levels.map((l) => l.productId).toSet().length;
  int get lowCount => levels.where((l) => l.isLow).length;
  int get expiredCount => levels.where((l) => l.isExpired).length;
  int get nearExpiryCount => levels.where((l) => l.isNearExpiry).length;

  List<StockLevelData> get filtered {
    if (query.trim().isEmpty) return levels;
    final q = query.trim().toLowerCase();
    return levels
        .where((l) =>
            l.productName.toLowerCase().contains(q) ||
            l.reference.toLowerCase().contains(q) ||
            (l.batchNumber?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  StockLevelListState copyWith({
    StockLevelStatus? status,
    List<StockLevelData>? levels,
    String? query,
    String? error,
  }) {
    return StockLevelListState(
      status: status ?? this.status,
      levels: levels ?? this.levels,
      query: query ?? this.query,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, levels, query, error];
}
DART_EOF

cat > lib/features/stock/presentation/widgets/stock_level_tile.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../data/models/stock_level_data.dart';

class StockLevelTile extends StatelessWidget {
  final StockLevelData level;
  final VoidCallback? onTap;

  const StockLevelTile({super.key, required this.level, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: level.isExpired
                  ? AppColors.danger.withValues(alpha: 0.4)
                  : level.isLow
                      ? AppColors.warning.withValues(alpha: 0.4)
                      : AppColors.borderLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(level.productName,
                        style: AppTypography.bodyStrong),
                  ),
                  Text(
                    '${level.qty} ${level.unit}',
                    style: AppTypography.bodyStrong.copyWith(
                      color: level.isLow
                          ? AppColors.warning
                          : AppColors.brandPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${level.reference} · ${level.locationName}',
                style: AppTypography.caption,
              ),
              if (level.batchNumber != null || level.expiryDate != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (level.batchNumber != null)
                      TypeBadge(
                        label: 'Lot ${level.batchNumber}',
                        tone: BadgeTone.gray,
                      ),
                    if (level.expiryDate != null)
                      TypeBadge(
                        label: level.isExpired
                            ? 'Périmé'
                            : 'DLC ${DateFormat('dd/MM/yy').format(level.expiryDate!)}',
                        tone: level.isExpired
                            ? BadgeTone.red
                            : level.isNearExpiry
                                ? BadgeTone.orange
                                : BadgeTone.green,
                      ),
                    if (level.isLow)
                      const TypeBadge(
                          label: 'Stock faible', tone: BadgeTone.yellow),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
DART_EOF

cat > lib/features/stock/presentation/screens/stock_level_list_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/cards/kpi_card.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../data/repositories/stock_repository.dart';
import '../bloc/stock_level_list_bloc.dart';
import '../widgets/stock_level_tile.dart';

class StockLevelListScreen extends StatelessWidget {
  const StockLevelListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StockLevelListBloc(getIt<StockRepository>())
        ..add(const LoadStockLevels()),
      child: const _StockLevelView(),
    );
  }
}

class _StockLevelView extends StatelessWidget {
  const _StockLevelView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Stock & Stérilisation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.go(Routes.alerts),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context
                .read<StockLevelListBloc>()
                .add(const RefreshStockLevels()),
          ),
        ],
      ),
      body: BlocBuilder<StockLevelListBloc, StockLevelListState>(
        builder: (context, state) {
          if (state.status == StockLevelStatus.loading &&
              state.levels.isEmpty) {
            return const LoadingView(message: 'Chargement du stock...');
          }
          if (state.status == StockLevelStatus.failure &&
              state.levels.isEmpty) {
            return ErrorView(
              message: state.error ?? 'Erreur',
              onRetry: () => context
                  .read<StockLevelListBloc>()
                  .add(const LoadStockLevels()),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => context
                .read<StockLevelListBloc>()
                .add(const RefreshStockLevels()),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tableau de bord des stocks',
                            style: AppTypography.pageTitle),
                        const SizedBox(height: AppSpacing.md),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 1.55,
                          children: [
                            KpiCard(
                              label: 'Références',
                              value: state.totalRefs.toString(),
                              icon: Icons.inventory_2_outlined,
                            ),
                            KpiCard(
                              label: 'Stock faible',
                              value: state.lowCount.toString(),
                              icon: Icons.warning_amber_outlined,
                            ),
                            KpiCard(
                              label: 'DLC proche',
                              value: state.nearExpiryCount.toString(),
                              icon: Icons.timer_outlined,
                            ),
                            KpiCard(
                              label: 'Périmés',
                              value: state.expiredCount.toString(),
                              icon: Icons.cancel_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const SectionHeader(title: 'Actions rapides'),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.remove_circle_outline,
                                label: 'Sortie',
                                onTap: () => context.go(Routes.stockIssue),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.edit_outlined,
                                label: 'Ajustement',
                                onTap: () => context.go(Routes.stockAdjust),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.swap_horiz,
                                label: 'Transfert',
                                onTap: () => context.go(Routes.stockTransfer),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const SectionHeader(title: 'Catalogue'),
                        AppSearchField(
                          hint: 'Rechercher un produit, lot...',
                          onChanged: (q) => context
                              .read<StockLevelListBloc>()
                              .add(SearchStockLevels(q)),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ),
                  ),
                ),
                if (state.filtered.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      title: 'Aucun produit',
                      message: 'Le catalogue est vide.',
                      icon: Icons.inventory_2_outlined,
                    ),
                  )
                else
                  SliverPadding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    sliver: SliverList.separated(
                      itemCount: state.filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) =>
                          StockLevelTile(level: state.filtered[i]),
                    ),
                  ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xxl)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 18, color: AppColors.brandPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(label,
                  style: AppTypography.caption, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
DART_EOF

cat > lib/features/stock/presentation/screens/stock_issue_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../cubit/stock_action_cubit.dart';

class StockIssueScreen extends StatelessWidget {
  const StockIssueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<StockActionCubit>(),
      child: const _StockIssueForm(),
    );
  }
}

class _StockIssueForm extends StatefulWidget {
  const _StockIssueForm();

  @override
  State<_StockIssueForm> createState() => _StockIssueFormState();
}

class _StockIssueFormState extends State<_StockIssueForm> {
  final _formKey = GlobalKey<FormState>();
  final _batchCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _batchCtrl.dispose();
    _locationCtrl.dispose();
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<StockActionCubit>().issue(
          batchId: _batchCtrl.text.trim(),
          locationId: _locationCtrl.text.trim(),
          qty: int.tryParse(_qtyCtrl.text.trim()) ?? 0,
          reason: _reasonCtrl.text.trim().isEmpty
              ? null
              : _reasonCtrl.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      AppSnackbar.show(context, 'Sortie enregistrée.',
          kind: SnackKind.success);
      context.pop();
    } else {
      AppSnackbar.show(context, 'Échec de l\'enregistrement.',
          kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Sortie de stock'),
      body: BlocBuilder<StockActionCubit, StockActionState>(
        builder: (context, state) {
          final isSubmitting = state.status == StockActionStatus.loading;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppTextField(
                  label: 'Identifiant du lot *',
                  hint: 'ex. UUID du lot',
                  controller: _batchCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Identifiant de l\'emplacement *',
                  hint: 'ex. UUID du local',
                  controller: _locationCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Quantité *',
                  hint: 'ex. 2',
                  keyboardType: TextInputType.number,
                  controller: _qtyCtrl,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requis.';
                    final n = int.tryParse(v.trim());
                    if (n == null || n <= 0) {
                      return 'Entrez un nombre positif.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextArea(
                  label: 'Motif (optionnel)',
                  controller: _reasonCtrl,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Enregistrer la sortie',
                  isLoading: isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
DART_EOF

cat > lib/features/stock/presentation/screens/stock_adjust_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../cubit/stock_action_cubit.dart';

class StockAdjustScreen extends StatelessWidget {
  const StockAdjustScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<StockActionCubit>(),
      child: const _StockAdjustForm(),
    );
  }
}

class _StockAdjustForm extends StatefulWidget {
  const _StockAdjustForm();

  @override
  State<_StockAdjustForm> createState() => _StockAdjustFormState();
}

class _StockAdjustFormState extends State<_StockAdjustForm> {
  final _formKey = GlobalKey<FormState>();
  final _batchCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _batchCtrl.dispose();
    _locationCtrl.dispose();
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<StockActionCubit>().adjust(
          batchId: _batchCtrl.text.trim(),
          locationId: _locationCtrl.text.trim(),
          qty: int.tryParse(_qtyCtrl.text.trim()) ?? 0,
          reason: _reasonCtrl.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      AppSnackbar.show(context, 'Ajustement enregistré.',
          kind: SnackKind.success);
      context.pop();
    } else {
      AppSnackbar.show(context, 'Échec de l\'enregistrement.',
          kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Ajustement de stock'),
      body: BlocBuilder<StockActionCubit, StockActionState>(
        builder: (context, state) {
          final isSubmitting = state.status == StockActionStatus.loading;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_outlined,
                          color: AppColors.warning),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Un ajustement corrige un écart d\'inventaire. '
                          'Le motif est obligatoire.',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Identifiant du lot *',
                  hint: 'ex. UUID du lot',
                  controller: _batchCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Identifiant de l\'emplacement *',
                  hint: 'ex. UUID du local',
                  controller: _locationCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Quantité (négatif pour retirer) *',
                  hint: 'ex. 5 ou -3',
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true),
                  controller: _qtyCtrl,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requis.';
                    if (int.tryParse(v.trim()) == null) {
                      return 'Entrez un nombre valide.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextArea(
                  label: 'Motif (obligatoire) *',
                  controller: _reasonCtrl,
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Le motif est obligatoire pour un ajustement.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Enregistrer l\'ajustement',
                  isLoading: isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
DART_EOF

cat > lib/features/stock/presentation/screens/stock_transfer_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../cubit/stock_action_cubit.dart';

class StockTransferScreen extends StatelessWidget {
  const StockTransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<StockActionCubit>(),
      child: const _StockTransferForm(),
    );
  }
}

class _StockTransferForm extends StatefulWidget {
  const _StockTransferForm();

  @override
  State<_StockTransferForm> createState() => _StockTransferFormState();
}

class _StockTransferFormState extends State<_StockTransferForm> {
  final _formKey = GlobalKey<FormState>();
  final _batchCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _batchCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<StockActionCubit>().transfer(
          batchId: _batchCtrl.text.trim(),
          fromLocationId: _fromCtrl.text.trim(),
          toLocationId: _toCtrl.text.trim(),
          qty: int.tryParse(_qtyCtrl.text.trim()) ?? 0,
          reason: _reasonCtrl.text.trim().isEmpty
              ? null
              : _reasonCtrl.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      AppSnackbar.show(context, 'Transfert enregistré.',
          kind: SnackKind.success);
      context.pop();
    } else {
      AppSnackbar.show(context, 'Échec de l\'enregistrement.',
          kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Transfert de stock'),
      body: BlocBuilder<StockActionCubit, StockActionState>(
        builder: (context, state) {
          final isSubmitting = state.status == StockActionStatus.loading;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppTextField(
                  label: 'Identifiant du lot *',
                  hint: 'ex. UUID du lot',
                  controller: _batchCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Depuis l\'emplacement *',
                  hint: 'ex. UUID source',
                  controller: _fromCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Vers l\'emplacement *',
                  hint: 'ex. UUID destination',
                  controller: _toCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Quantité *',
                  hint: 'ex. 3',
                  keyboardType: TextInputType.number,
                  controller: _qtyCtrl,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requis.';
                    final n = int.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Entrez un nombre positif.';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextArea(
                  label: 'Motif (optionnel)',
                  controller: _reasonCtrl,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Enregistrer le transfert',
                  isLoading: isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
DART_EOF

echo "   ✔ stock written"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 5 — Audit
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Phase 5 — Audit"
mkdir -p lib/features/history/data/models \
         lib/features/history/data/datasources \
         lib/features/history/data/repositories \
         lib/features/history/presentation/bloc \
         lib/features/history/presentation/screens

cat > lib/features/history/data/models/audit_event_data.dart << 'DART_EOF'
import 'package:equatable/equatable.dart';

class AuditEventData extends Equatable {
  final String id;
  final String? actorId;
  final String? actorLabel;
  final String action;
  final String? subjectType;
  final String? subjectId;
  final String? reason;
  final DateTime occurredAt;

  const AuditEventData({
    required this.id,
    this.actorId,
    this.actorLabel,
    required this.action,
    this.subjectType,
    this.subjectId,
    this.reason,
    required this.occurredAt,
  });

  factory AuditEventData.fromJson(Map<String, dynamic> json) => AuditEventData(
        id: json['id']?.toString() ?? '',
        actorId: json['actor_id']?.toString(),
        actorLabel: json['actor_label_snapshot']?.toString(),
        action: json['action']?.toString() ?? '',
        subjectType: json['subject_type']?.toString(),
        subjectId: json['subject_id']?.toString(),
        reason: json['reason']?.toString(),
        occurredAt:
            DateTime.tryParse(json['occurred_at']?.toString() ?? '') ??
                DateTime.now(),
      );

  String get actionLabel {
    const map = {
      'auth.login_succeeded': 'Connexion réussie',
      'auth.login_denied': 'Échec de connexion',
      'tenant.registered': 'Cabinet enregistré',
      'product.created': 'Produit créé',
      'cycle.created': 'Cycle créé',
      'cycle.started': 'Cycle démarré',
      'cycle.completed': 'Cycle terminé',
      'cycle.released': 'Cycle libéré',
      'cycle.rejected': 'Cycle rejeté',
      'label.printed': 'Étiquette imprimée',
      'label_usage.recorded': 'Utilisation enregistrée',
      'stock_movement.issued': 'Sortie de stock',
      'stock_movement.adjusted': 'Ajustement de stock',
    };
    return map[action] ?? action;
  }

  @override
  List<Object?> get props =>
      [id, actorId, actorLabel, action, subjectType, subjectId, occurredAt];
}
DART_EOF

cat > lib/features/history/data/datasources/audit_remote_datasource.dart << 'DART_EOF'
import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../models/audit_event_data.dart';

class AuditRemoteDatasource {
  final Dio _dio;
  AuditRemoteDatasource(this._dio);

  Future<List<AuditEventData>> list({
    String? cursor,
    String? action,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.auditEvents,
        queryParameters: {
          if (cursor != null) 'cursor': cursor,
          if (action != null && action.isNotEmpty) 'filter[action]': action,
          'per_page': 30,
        },
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => AuditEventData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
DART_EOF

cat > lib/features/history/data/repositories/audit_repository.dart << 'DART_EOF'
import '../datasources/audit_remote_datasource.dart';
import '../models/audit_event_data.dart';

class AuditRepository {
  final AuditRemoteDatasource _remote;
  AuditRepository(this._remote);

  Future<List<AuditEventData>> list({String? cursor, String? action}) =>
      _remote.list(cursor: cursor, action: action);
}
DART_EOF

cat > lib/features/history/presentation/bloc/audit_list_bloc.dart << 'DART_EOF'
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/audit_event_data.dart';
import '../../data/repositories/audit_repository.dart';

part 'audit_list_event.dart';
part 'audit_list_state.dart';

class AuditListBloc extends Bloc<AuditListEvent, AuditListState> {
  final AuditRepository _repository;

  AuditListBloc(this._repository) : super(const AuditListState()) {
    on<LoadAuditEvents>(_onLoad);
    on<RefreshAuditEvents>(_onRefresh);
    on<FilterAuditEvents>(_onFilter);
  }

  Future<void> _onLoad(
    LoadAuditEvents event,
    Emitter<AuditListState> emit,
  ) async {
    emit(state.copyWith(status: AuditStatus.loading, error: null));
    try {
      final events = await _repository.list(action: state.actionFilter);
      emit(state.copyWith(status: AuditStatus.success, events: events));
    } on ApiException catch (e) {
      emit(state.copyWith(status: AuditStatus.failure, error: e.message));
    }
  }

  Future<void> _onRefresh(
    RefreshAuditEvents event,
    Emitter<AuditListState> emit,
  ) async {
    try {
      final events = await _repository.list(action: state.actionFilter);
      emit(state.copyWith(status: AuditStatus.success, events: events));
    } on ApiException catch (e) {
      emit(state.copyWith(status: AuditStatus.failure, error: e.message));
    }
  }

  void _onFilter(FilterAuditEvents event, Emitter<AuditListState> emit) {
    emit(state.copyWith(actionFilter: event.action));
    add(const LoadAuditEvents());
  }
}
DART_EOF

cat > lib/features/history/presentation/bloc/audit_list_event.dart << 'DART_EOF'
part of 'audit_list_bloc.dart';

abstract class AuditListEvent extends Equatable {
  const AuditListEvent();
  @override
  List<Object?> get props => [];
}

class LoadAuditEvents extends AuditListEvent {
  const LoadAuditEvents();
}

class RefreshAuditEvents extends AuditListEvent {
  const RefreshAuditEvents();
}

class FilterAuditEvents extends AuditListEvent {
  final String? action;
  const FilterAuditEvents(this.action);
  @override
  List<Object?> get props => [action];
}
DART_EOF

cat > lib/features/history/presentation/bloc/audit_list_state.dart << 'DART_EOF'
part of 'audit_list_bloc.dart';

enum AuditStatus { initial, loading, success, failure }

class AuditListState extends Equatable {
  final AuditStatus status;
  final List<AuditEventData> events;
  final String? actionFilter;
  final String? error;

  const AuditListState({
    this.status = AuditStatus.initial,
    this.events = const [],
    this.actionFilter,
    this.error,
  });

  AuditListState copyWith({
    AuditStatus? status,
    List<AuditEventData>? events,
    String? actionFilter,
    String? error,
    bool clearFilter = false,
  }) {
    return AuditListState(
      status: status ?? this.status,
      events: events ?? this.events,
      actionFilter: clearFilter ? null : (actionFilter ?? this.actionFilter),
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, events, actionFilter, error];
}
DART_EOF

cat > lib/features/history/presentation/screens/audit_list_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/filter_chip_row.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/audit_event_data.dart';
import '../../data/repositories/audit_repository.dart';
import '../bloc/audit_list_bloc.dart';

class AuditListScreen extends StatelessWidget {
  const AuditListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuditListBloc(getIt<AuditRepository>())
        ..add(const LoadAuditEvents()),
      child: const _AuditListView(),
    );
  }
}

class _AuditListView extends StatelessWidget {
  const _AuditListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Journal d\'Audit',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context
                .read<AuditListBloc>()
                .add(const RefreshAuditEvents()),
          ),
        ],
      ),
      body: Column(
        children: [
          BlocBuilder<AuditListBloc, AuditListState>(
            builder: (context, state) {
              return FilterChipRow<String?>(
                selected: state.actionFilter,
                onSelected: (v) =>
                    context.read<AuditListBloc>().add(FilterAuditEvents(v)),
                options: const [
                  FilterChipOption(value: null, label: 'Tous'),
                  FilterChipOption(
                      value: 'auth.login_succeeded', label: 'Connexions'),
                  FilterChipOption(value: 'cycle.started', label: 'Cycles'),
                  FilterChipOption(
                      value: 'label_usage.recorded', label: 'Utilisations'),
                  FilterChipOption(
                      value: 'product.created', label: 'Produits'),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: BlocBuilder<AuditListBloc, AuditListState>(
              builder: (context, state) {
                if (state.status == AuditStatus.loading &&
                    state.events.isEmpty) {
                  return const LoadingView();
                }
                if (state.status == AuditStatus.failure &&
                    state.events.isEmpty) {
                  return ErrorView(
                    message: state.error ?? 'Erreur',
                    onRetry: () => context
                        .read<AuditListBloc>()
                        .add(const LoadAuditEvents()),
                  );
                }
                if (state.events.isEmpty) {
                  return const EmptyView(
                    title: 'Aucun événement',
                    message: 'Aucune action enregistrée pour ce filtre.',
                    icon: Icons.history_toggle_off,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => context
                      .read<AuditListBloc>()
                      .add(const RefreshAuditEvents()),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: state.events.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) =>
                        _AuditTile(event: state.events[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final AuditEventData event;
  const _AuditTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(event.actionLabel,
                    style: AppTypography.bodyStrong),
              ),
              Text(
                DateFormat('dd/MM/yy HH:mm').format(event.occurredAt),
                style: AppTypography.caption,
              ),
            ],
          ),
          if (event.actorLabel != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(event.actorLabel!,
                      style: AppTypography.caption),
                ),
              ],
            ),
          ],
          if (event.subjectType != null) ...[
            const SizedBox(height: 2),
            Text(
              event.subjectType!,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
DART_EOF

echo "   ✔ audit written"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 6 — Compliance
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Phase 6 — Compliance"
mkdir -p lib/features/compliance/data/models \
         lib/features/compliance/data/datasources \
         lib/features/compliance/data/repositories \
         lib/features/compliance/presentation/bloc

cat > lib/features/compliance/data/models/non_conformity_data.dart << 'DART_EOF'
import 'package:equatable/equatable.dart';

class NonConformityData extends Equatable {
  final String id;
  final String reference;
  final String kind;
  final String status;
  final String title;
  final String description;
  final String? cycleNumber;
  final String? batchNumber;
  final int? sachetsAffected;
  final String? openedBy;
  final DateTime openedAt;
  final String? resolution;

  const NonConformityData({
    required this.id,
    required this.reference,
    required this.kind,
    required this.status,
    required this.title,
    required this.description,
    this.cycleNumber,
    this.batchNumber,
    this.sachetsAffected,
    this.openedBy,
    required this.openedAt,
    this.resolution,
  });

  bool get isOpen => status == 'open';

  factory NonConformityData.fromJson(Map<String, dynamic> json) =>
      NonConformityData(
        id: json['id']?.toString() ?? '',
        reference: json['reference']?.toString() ?? '',
        kind: json['kind']?.toString() ?? 'correction',
        status: json['status']?.toString() ?? 'open',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        cycleNumber: json['cycle_number']?.toString(),
        batchNumber: json['batch_number']?.toString(),
        sachetsAffected: (json['sachets_affected'] as num?)?.toInt(),
        openedBy: json['opened_by']?.toString(),
        openedAt: DateTime.tryParse(json['opened_at']?.toString() ?? '') ??
            DateTime.now(),
        resolution: json['resolution']?.toString(),
      );

  @override
  List<Object?> get props => [id, reference, status, kind, openedAt];
}
DART_EOF

cat > lib/features/compliance/data/datasources/non_conformity_remote_datasource.dart << 'DART_EOF'
import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/non_conformity_data.dart';

class NonConformityRemoteDatasource {
  final Dio _dio;
  NonConformityRemoteDatasource(this._dio);

  Future<List<NonConformityData>> list({String? status}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.nonConformities,
        queryParameters: {
          if (status != null) 'status': status,
          'per_page': 50,
        },
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => NonConformityData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> resolve(String id, {required String resolution}) async {
    try {
      await _dio.post(
        ApiEndpoints.nonConformityResolve(id),
        data: {'resolution': resolution},
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
DART_EOF

cat > lib/features/compliance/data/repositories/non_conformity_repository.dart << 'DART_EOF'
import '../datasources/non_conformity_remote_datasource.dart';
import '../models/non_conformity_data.dart';

class NonConformityRepository {
  final NonConformityRemoteDatasource _remote;
  NonConformityRepository(this._remote);

  Future<List<NonConformityData>> list({String? status}) =>
      _remote.list(status: status);

  Future<void> resolve(String id, {required String resolution}) =>
      _remote.resolve(id, resolution: resolution);
}
DART_EOF

cat > lib/features/compliance/presentation/bloc/non_conformity_list_bloc.dart << 'DART_EOF'
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/non_conformity_data.dart';
import '../../data/repositories/non_conformity_repository.dart';

part 'non_conformity_list_event.dart';
part 'non_conformity_list_state.dart';

class NonConformityListBloc
    extends Bloc<NonConformityListEvent, NonConformityListState> {
  final NonConformityRepository _repository;

  NonConformityListBloc(this._repository)
      : super(const NonConformityListState()) {
    on<LoadNonConformities>(_onLoad);
    on<FilterNonConformities>(_onFilter);
  }

  Future<void> _onLoad(
    LoadNonConformities event,
    Emitter<NonConformityListState> emit,
  ) async {
    emit(state.copyWith(status: NonConformityStatus.loading));
    try {
      final items = await _repository.list(status: state.statusFilter);
      emit(state.copyWith(
        status: NonConformityStatus.success,
        items: items,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: NonConformityStatus.failure,
        error: e.message,
      ));
    }
  }

  void _onFilter(
    FilterNonConformities event,
    Emitter<NonConformityListState> emit,
  ) {
    emit(state.copyWith(statusFilter: event.status));
    add(const LoadNonConformities());
  }
}
DART_EOF

cat > lib/features/compliance/presentation/bloc/non_conformity_list_event.dart << 'DART_EOF'
part of 'non_conformity_list_bloc.dart';

abstract class NonConformityListEvent extends Equatable {
  const NonConformityListEvent();
  @override
  List<Object?> get props => [];
}

class LoadNonConformities extends NonConformityListEvent {
  const LoadNonConformities();
}

class FilterNonConformities extends NonConformityListEvent {
  final String? status;
  const FilterNonConformities(this.status);
  @override
  List<Object?> get props => [status];
}
DART_EOF

cat > lib/features/compliance/presentation/bloc/non_conformity_list_state.dart << 'DART_EOF'
part of 'non_conformity_list_bloc.dart';

enum NonConformityStatus { initial, loading, success, failure }

class NonConformityListState extends Equatable {
  final NonConformityStatus status;
  final List<NonConformityData> items;
  final String? statusFilter;
  final String? error;

  const NonConformityListState({
    this.status = NonConformityStatus.initial,
    this.items = const [],
    this.statusFilter,
    this.error,
  });

  NonConformityListState copyWith({
    NonConformityStatus? status,
    List<NonConformityData>? items,
    String? statusFilter,
    String? error,
    bool clearFilter = false,
  }) {
    return NonConformityListState(
      status: status ?? this.status,
      items: items ?? this.items,
      statusFilter: clearFilter ? null : (statusFilter ?? this.statusFilter),
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, items, statusFilter, error];
}
DART_EOF

cat > lib/features/compliance/presentation/screens/non_conformities_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/non_conformity_data.dart';
import '../../data/repositories/non_conformity_repository.dart';
import '../bloc/non_conformity_list_bloc.dart';

class NonConformitiesScreen extends StatelessWidget {
  const NonConformitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NonConformityListBloc(getIt<NonConformityRepository>())
        ..add(const LoadNonConformities()),
      child: const _NonConformitiesView(),
    );
  }
}

class _NonConformitiesView extends StatelessWidget {
  const _NonConformitiesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Non-Conformités & Rappels',
        actions: [
          IconButton(
            icon: const Icon(Icons.notification_important_outlined,
                color: AppColors.danger),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<NonConformityListBloc, NonConformityListState>(
        builder: (context, state) {
          return Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    _Chip(
                      label: 'Toutes (${state.items.length})',
                      selected: state.statusFilter == null,
                      onTap: () => context
                          .read<NonConformityListBloc>()
                          .add(const FilterNonConformities(null)),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _Chip(
                      label: 'En cours',
                      selected: state.statusFilter == 'open',
                      onTap: () => context
                          .read<NonConformityListBloc>()
                          .add(const FilterNonConformities('open')),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _Chip(
                      label: 'Résolues',
                      selected: state.statusFilter == 'resolved',
                      onTap: () => context
                          .read<NonConformityListBloc>()
                          .add(const FilterNonConformities('resolved')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: _Body(state: state),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final NonConformityListState state;
  const _Body({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.status == NonConformityStatus.loading && state.items.isEmpty) {
      return const LoadingView();
    }
    if (state.status == NonConformityStatus.failure && state.items.isEmpty) {
      return ErrorView(message: state.error ?? 'Erreur');
    }
    if (state.items.isEmpty) {
      return const EmptyView(
        title: 'Aucune non-conformité',
        message: 'Aucun incident enregistré.',
        icon: Icons.verified_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) => _NcCard(item: state.items[i]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimary : AppColors.backgroundSubtle,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.brandPrimary : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodyStrong.copyWith(
            color: selected
                ? AppColors.textOnBrand
                : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _NcCard extends StatelessWidget {
  final NonConformityData item;
  const _NcCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final (typeTone, typeLabel) = switch (item.kind) {
      'recall' => (BadgeTone.red, 'RECALL'),
      'quarantine' => (BadgeTone.orange, 'QUARANTAINE'),
      _ => (BadgeTone.blue, 'CORRECTION'),
    };
    final statusTone = item.isOpen ? BadgeTone.yellow : BadgeTone.green;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: item.isOpen
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TypeBadge(label: typeLabel, tone: typeTone),
              const SizedBox(width: AppSpacing.sm),
              Text(item.reference, style: AppTypography.caption),
              const Spacer(),
              TypeBadge(
                label: item.isOpen ? 'En cours' : 'Résolu',
                tone: statusTone,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(item.title, style: AppTypography.bodyStrong),
          const SizedBox(height: AppSpacing.xs),
          Text(item.description, style: AppTypography.body),
          if (item.batchNumber != null || item.cycleNumber != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (item.cycleNumber != null)
                  _Tag(
                    icon: Icons.autorenew,
                    label: 'Cycle ${item.cycleNumber}',
                  ),
                if (item.batchNumber != null)
                  _Tag(
                    icon: Icons.inventory_2_outlined,
                    label: 'Lot ${item.batchNumber}',
                  ),
                if (item.sachetsAffected != null)
                  _Tag(
                    icon: Icons.numbers,
                    label: '${item.sachetsAffected} sachet(s)',
                  ),
              ],
            ),
          ],
          if (item.openedBy != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ouvert le ${item.openedAt.day.toString().padLeft(2, '0')}/${item.openedAt.month.toString().padLeft(2, '0')}/${item.openedAt.year} par ${item.openedBy}',
              style: AppTypography.caption,
            ),
          ],
          if (item.resolution != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Résolution : ${item.resolution}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Tag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}
DART_EOF

echo "   ✔ compliance written"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 7 — Team & Sites
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Phase 7 — Team & Sites"
mkdir -p lib/features/identity/data/models \
         lib/features/identity/data/datasources \
         lib/features/identity/data/repositories \
         lib/features/identity/presentation/bloc \
         lib/features/tenancy/data/models \
         lib/features/tenancy/data/datasources \
         lib/features/tenancy/data/repositories

cat > lib/features/identity/data/models/team_member_data.dart << 'DART_EOF'
import 'package:equatable/equatable.dart';

class TeamMemberData extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String role;
  final bool active;
  final String? locationLabel;
  final DateTime? createdAt;
  final DateTime? lastSessionAt;

  const TeamMemberData({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    this.locationLabel,
    this.createdAt,
    this.lastSessionAt,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory TeamMemberData.fromJson(Map<String, dynamic> json) => TeamMemberData(
        id: json['id']?.toString() ?? '',
        userId: json['user_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        role: json['role']?.toString() ?? 'viewer',
        active: json['active'] as bool? ?? true,
        locationLabel: json['location_label']?.toString(),
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? ''),
        lastSessionAt:
            DateTime.tryParse(json['last_session_at']?.toString() ?? ''),
      );

  @override
  List<Object?> get props => [id, userId, role, active];
}
DART_EOF

cat > lib/features/identity/data/datasources/team_remote_datasource.dart << 'DART_EOF'
import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../models/team_member_data.dart';

class TeamRemoteDatasource {
  final Dio _dio;
  TeamRemoteDatasource(this._dio);

  Future<List<TeamMemberData>> list() async {
    try {
      final res = await _dio.get(
        '/v1/members',
        queryParameters: {'per_page': 100},
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => TeamMemberData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const [];
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> invite({
    required String email,
    required String role,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.invitations,
        data: {'email': email, 'role': role},
        options: Options(
          headers: {'Idempotency-Key': generateIdempotencyKey()},
        ),
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  Future<void> disable(String tenantUserId) async {
    try {
      await _dio.delete(ApiEndpoints.member(tenantUserId));
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
DART_EOF

cat > lib/features/identity/data/repositories/team_repository.dart << 'DART_EOF'
import '../datasources/team_remote_datasource.dart';
import '../models/team_member_data.dart';

class TeamRepository {
  final TeamRemoteDatasource _remote;
  TeamRepository(this._remote);

  Future<List<TeamMemberData>> list() => _remote.list();
  Future<void> invite({required String email, required String role}) =>
      _remote.invite(email: email, role: role);
  Future<void> disable(String tenantUserId) => _remote.disable(tenantUserId);
}
DART_EOF

cat > lib/features/identity/presentation/bloc/team_list_bloc.dart << 'DART_EOF'
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/team_member_data.dart';
import '../../data/repositories/team_repository.dart';

part 'team_list_event.dart';
part 'team_list_state.dart';

class TeamListBloc extends Bloc<TeamListEvent, TeamListState> {
  final TeamRepository _repository;

  TeamListBloc(this._repository) : super(const TeamListState()) {
    on<LoadTeam>(_onLoad);
    on<FilterTeam>(_onFilter);
    on<InviteTeamMember>(_onInvite);
  }

  Future<void> _onLoad(LoadTeam event, Emitter<TeamListState> emit) async {
    emit(state.copyWith(status: TeamStatus.loading, error: null));
    try {
      final members = await _repository.list();
      emit(state.copyWith(status: TeamStatus.success, members: members));
    } on ApiException catch (e) {
      emit(state.copyWith(status: TeamStatus.failure, error: e.message));
    }
  }

  void _onFilter(FilterTeam event, Emitter<TeamListState> emit) {
    emit(state.copyWith(roleFilter: event.role));
  }

  Future<void> _onInvite(
    InviteTeamMember event,
    Emitter<TeamListState> emit,
  ) async {
    try {
      await _repository.invite(email: event.email, role: event.role);
      add(const LoadTeam());
      emit(state.copyWith(inviteSuccess: true));
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message, inviteSuccess: false));
    }
  }
}
DART_EOF

cat > lib/features/identity/presentation/bloc/team_list_event.dart << 'DART_EOF'
part of 'team_list_bloc.dart';

abstract class TeamListEvent extends Equatable {
  const TeamListEvent();
  @override
  List<Object?> get props => [];
}

class LoadTeam extends TeamListEvent {
  const LoadTeam();
}

class FilterTeam extends TeamListEvent {
  final String? role;
  const FilterTeam(this.role);
  @override
  List<Object?> get props => [role];
}

class InviteTeamMember extends TeamListEvent {
  final String email;
  final String role;
  const InviteTeamMember({required this.email, required this.role});
  @override
  List<Object?> get props => [email, role];
}
DART_EOF

cat > lib/features/identity/presentation/bloc/team_list_state.dart << 'DART_EOF'
part of 'team_list_bloc.dart';

enum TeamStatus { initial, loading, success, failure }

class TeamListState extends Equatable {
  final TeamStatus status;
  final List<TeamMemberData> members;
  final String? roleFilter;
  final String? error;
  final bool inviteSuccess;

  const TeamListState({
    this.status = TeamStatus.initial,
    this.members = const [],
    this.roleFilter,
    this.error,
    this.inviteSuccess = false,
  });

  List<TeamMemberData> get filtered {
    if (roleFilter == null) return members;
    return members.where((m) => m.role == roleFilter).toList();
  }

  TeamListState copyWith({
    TeamStatus? status,
    List<TeamMemberData>? members,
    String? roleFilter,
    String? error,
    bool? inviteSuccess,
    bool clearFilter = false,
  }) {
    return TeamListState(
      status: status ?? this.status,
      members: members ?? this.members,
      roleFilter: clearFilter ? null : (roleFilter ?? this.roleFilter),
      error: error ?? this.error,
      inviteSuccess: inviteSuccess ?? this.inviteSuccess,
    );
  }

  @override
  List<Object?> get props =>
      [status, members, roleFilter, error, inviteSuccess];
}
DART_EOF

cat > lib/features/tenancy/data/models/site_data.dart << 'DART_EOF'
import 'package:equatable/equatable.dart';

class SiteData extends Equatable {
  final String id;
  final String name;
  final String? kind;
  final String? address;
  final int roomCount;
  final int deviceCount;
  final int armoryCount;

  const SiteData({
    required this.id,
    required this.name,
    this.kind,
    this.address,
    this.roomCount = 0,
    this.deviceCount = 0,
    this.armoryCount = 0,
  });

  factory SiteData.fromJson(Map<String, dynamic> json) => SiteData(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        kind: json['kind']?.toString(),
        address: json['address']?.toString(),
        roomCount: (json['room_count'] as num?)?.toInt() ?? 0,
        deviceCount: (json['device_count'] as num?)?.toInt() ?? 0,
        armoryCount: (json['armory_count'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [id, name, kind];
}
DART_EOF

cat > lib/features/tenancy/data/datasources/site_remote_datasource.dart << 'DART_EOF'
import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../../core/errors/error_mapper.dart';
import '../models/site_data.dart';

class SiteRemoteDatasource {
  final Dio _dio;
  SiteRemoteDatasource(this._dio);

  Future<List<SiteData>> list() async {
    try {
      final res = await _dio.get(ApiEndpoints.sites);
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => SiteData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
DART_EOF

cat > lib/features/tenancy/data/repositories/site_repository.dart << 'DART_EOF'
import '../datasources/site_remote_datasource.dart';
import '../models/site_data.dart';

class SiteRepository {
  final SiteRemoteDatasource _remote;
  SiteRepository(this._remote);
  Future<List<SiteData>> list() => _remote.list();
}
DART_EOF

cat > lib/features/tenancy/presentation/screens/site_list_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/site_data.dart';
import '../../data/repositories/site_repository.dart';

class SiteListScreen extends StatefulWidget {
  const SiteListScreen({super.key});

  @override
  State<SiteListScreen> createState() => _SiteListScreenState();
}

class _SiteListScreenState extends State<SiteListScreen> {
  late Future<List<SiteData>> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<SiteRepository>().list();
  }

  Future<void> _refresh() async {
    setState(() => _future = getIt<SiteRepository>().list());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Sites & Espaces Cliniques'),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<SiteData>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            if (snap.hasError) {
              return ErrorView(
                message: 'Impossible de charger les sites.',
                onRetry: _refresh,
              );
            }
            final sites = snap.data ?? const <SiteData>[];
            if (sites.isEmpty) {
              return const EmptyView(
                title: 'Aucun site',
                message: 'Aucun site clinique configuré.',
                icon: Icons.business_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: sites.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) => _SiteCard(site: sites[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  final SiteData site;
  const _SiteCard({required this.site});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  (site.kind ?? 'SITE').toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.business, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            site.name,
            style: AppTypography.sectionTitle.copyWith(color: Colors.white),
          ),
          if (site.address != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    site.address!,
                    style: AppTypography.caption
                        .copyWith(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _StatChip(label: '${site.roomCount} salle(s)'),
              _StatChip(label: '${site.deviceCount} appareil(s)'),
              _StatChip(label: '${site.armoryCount} armoire(s)'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  const _StatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: Colors.white),
      ),
    );
  }
}
DART_EOF

echo "   ✔ team & sites written"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 8 — Settings & About
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Phase 8 — Settings & About"
mkdir -p lib/features/settings/presentation/screens

cat > lib/features/settings/presentation/screens/settings_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/build_info.dart';
import '../../../../core/config/env.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionStore>();
    final name = session.userName ?? 'Utilisateur';
    final email = session.userEmail ?? '';
    final role = session.role ?? 'staff';
    final tenant = session.tenantName ?? '';

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Paramètres', showBack: false),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const _SectionHeader('Mon compte'),
          _InfoTile(icon: Icons.person_outline, label: 'Nom', value: name),
          _InfoTile(icon: Icons.email_outlined, label: 'E-mail', value: email),
          _InfoTile(icon: Icons.badge_outlined, label: 'Rôle', value: role),
          _InfoTile(
            icon: Icons.business_outlined,
            label: 'Cabinet',
            value: tenant,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader('Session'),
          SecondaryButton(
            label: 'Se déconnecter',
            icon: Icons.logout,
            onPressed: () async {
              final ok = await ConfirmationDialog.show(
                context,
                title: 'Se déconnecter ?',
                message: 'Vous serez redirigé vers l\'écran de connexion.',
                confirmLabel: 'Se déconnecter',
                isDestructive: true,
              );
              if (ok && context.mounted) {
                context.read<AuthBloc>().add(const AuthLogoutRequested());
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'Se déconnecter partout',
            icon: Icons.logout_outlined,
            onPressed: () async {
              final ok = await ConfirmationDialog.show(
                context,
                title: 'Se déconnecter partout ?',
                message: 'Toutes les sessions actives seront révoquées.',
                confirmLabel: 'Confirmer',
                isDestructive: true,
              );
              if (ok && context.mounted) {
                context
                    .read<AuthBloc>()
                    .add(const AuthLogoutEverywhereRequested());
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader('Application'),
          _InfoTile(
            icon: Icons.info_outline,
            label: 'Version',
            value: BuildInfo.fullVersion,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                const Icon(Icons.cloud_outlined,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Environnement', style: AppTypography.label),
                ),
                StatusBadge(
                  label: Env.environment,
                  tone: Env.isProduction
                      ? StatusTone.success
                      : Env.isStaging
                          ? StatusTone.warning
                          : StatusTone.info,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader('Support'),
          _LinkTile(
            icon: Icons.help_outline,
            label: 'À propos de SteryMed',
            onTap: () => context.go(Routes.about),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.label.copyWith(
          letterSpacing: 0.6,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.label)),
          Text(value, style: AppTypography.bodyStrong),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.brandPrimary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(label, style: AppTypography.bodyStrong)),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
DART_EOF

cat > lib/features/settings/presentation/screens/about_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';

import '../../../../core/config/build_info.dart';
import '../../../../core/config/env.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/misc/app_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'À propos'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const Center(child: AppLogo(height: 56)),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'SteryMed',
            textAlign: TextAlign.center,
            style: AppTypography.pageTitle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Traçabilité stérilisation et suivi des dossiers prothétiques',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _Row(label: 'Version', value: BuildInfo.fullVersion),
          _Row(label: 'Environnement', value: Env.environment),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Conçu pour les cabinets dentaires français. '
            'Les données sont chiffrées et l\'audit est immuable.',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.label)),
          Text(value, style: AppTypography.bodyStrong),
        ],
      ),
    );
  }
}
DART_EOF

echo "   ✔ settings written"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 9 — Cycles detail (transition actions)
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Phase 9 — Cycle detail transitions"

cat > lib/features/cycles/presentation/screens/cycle_detail_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../data/models/cycle_data.dart';
import '../bloc/cycle_detail_bloc.dart';
import '../bloc/cycle_transition_bloc.dart';
import '../widgets/control_test_row.dart';
import '../widgets/cycle_attachment_grid.dart';
import '../widgets/cycle_item_row.dart';
import '../widgets/cycle_status_badge.dart';
import '../widgets/cycle_timeline.dart';
import '../widgets/transition_confirm_dialog.dart';

class CycleDetailScreen extends StatelessWidget {
  final String cycleId;
  const CycleDetailScreen({super.key, required this.cycleId});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (ctx) =>
              CycleDetailBloc(ctx.read())..add(LoadCycleDetail(cycleId)),
        ),
        BlocProvider(create: (ctx) => CycleTransitionBloc(ctx.read())),
      ],
      child: _CycleDetailView(cycleId: cycleId),
    );
  }
}

class _CycleDetailView extends StatelessWidget {
  final String cycleId;
  const _CycleDetailView({required this.cycleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Détail du cycle')),
      body: BlocListener<CycleTransitionBloc, CycleTransitionState>(
        listenWhen: (p, c) => p.status != c.status,
        listener: (context, state) {
          if (state.status == CycleTransitionStatus.success) {
            context.read<CycleDetailBloc>().add(RefreshCycleDetail(cycleId));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cycle mis à jour.')),
            );
          }
          if (state.status == CycleTransitionStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error ?? 'Erreur')),
            );
          }
        },
        child: BlocBuilder<CycleDetailBloc, CycleDetailState>(
          builder: (context, state) {
            if (state.status == CycleDetailStatus.loading &&
                state.cycle == null) {
              return const LoadingView();
            }
            if (state.status == CycleDetailStatus.failure) {
              return ErrorView(
                message: state.error ?? 'Erreur',
                onRetry: () => context
                    .read<CycleDetailBloc>()
                    .add(LoadCycleDetail(cycleId)),
              );
            }
            final c = state.cycle;
            if (c == null) return const SizedBox.shrink();

            return RefreshIndicator(
              onRefresh: () async => context
                  .read<CycleDetailBloc>()
                  .add(RefreshCycleDetail(cycleId)),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Cycle ${c.number}',
                            style: AppTypography.pageTitle),
                      ),
                      CycleStatusBadge(status: c.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _infoCard(c),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(title: 'Chronologie'),
                  CycleTimeline(cycle: c),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: 'Instruments (${state.items.length})',
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => context.go(Routes.cyclesItems(c.id)),
                    ),
                  ),
                  if (state.items.isEmpty)
                    const Text('Aucun instrument enregistré.',
                        style: AppTypography.caption)
                  else
                    ...state.items.map((i) => CycleItemRow(item: i)),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: 'Contrôles (${state.controlTests.length})',
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () =>
                          context.go(Routes.cyclesControlTests(c.id)),
                    ),
                  ),
                  if (state.controlTests.isEmpty)
                    const Text('Aucun contrôle enregistré.',
                        style: AppTypography.caption)
                  else
                    ...state.controlTests.map((t) => ControlTestRow(test: t)),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: 'Pièces jointes (${state.attachments.length})',
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () =>
                          context.go(Routes.cyclesAttachments(c.id)),
                    ),
                  ),
                  CycleAttachmentGrid(attachments: state.attachments),
                  const SizedBox(height: AppSpacing.xxl),
                  _actionButton(context, c.id, c.status),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoCard(CycleData c) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          _row(Icons.precision_manufacturing_outlined, 'Appareil',
              c.deviceName),
          if (c.programName != null)
            _row(Icons.settings_suggest_outlined, 'Programme',
                c.programName!),
          if (c.operatorName != null)
            _row(Icons.person_outline, 'Opérateur', c.operatorName!),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: AppTypography.label),
          const Spacer(),
          Text(value, style: AppTypography.bodyStrong),
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context, String cycleId, String status) {
    switch (status) {
      case 'created':
        return PrimaryButton(
          label: 'Démarrer le cycle',
          icon: Icons.play_arrow,
          onPressed: () async {
            final ok = await TransitionConfirmDialog.show(
              context,
              title: 'Démarrer le cycle ?',
              message: 'Le cycle passera en cours de traitement.',
            );
            if (ok && context.mounted) {
              context.read<CycleTransitionBloc>().add(StartCycle(cycleId));
            }
          },
        );
      case 'in_progress':
        return PrimaryButton(
          label: 'Marquer comme terminé',
          icon: Icons.check,
          onPressed: () async {
            final ok = await TransitionConfirmDialog.show(
              context,
              title: 'Terminer le cycle ?',
              message: 'Vous pourrez ensuite soumettre pour libération.',
            );
            if (ok && context.mounted) {
              context.read<CycleTransitionBloc>().add(CompleteCycle(cycleId));
            }
          },
        );
      case 'completed':
        return PrimaryButton(
          label: 'Soumettre pour libération',
          icon: Icons.assignment_turned_in_outlined,
          onPressed: () async {
            final ok = await TransitionConfirmDialog.show(
              context,
              title: 'Soumettre pour libération ?',
              message: 'Un responsable devra valider la conformité.',
            );
            if (ok && context.mounted) {
              context
                  .read<CycleTransitionBloc>()
                  .add(SubmitCycleForRelease(cycleId));
            }
          },
        );
      case 'awaiting_release':
        return PrimaryButton(
          label: 'Prendre la décision de libération',
          icon: Icons.verified_outlined,
          onPressed: () => context.go(Routes.cyclesRelease(cycleId)),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
DART_EOF

echo "   ✔ cycle detail written"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 10 — DI registration
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Phase 10 — DI registration"

cat > lib/di/features_di.dart << 'DART_EOF'
import 'package:get_it/get_it.dart';

import '../core/network/dio_client.dart';
import '../core/storage/session_store.dart';
import '../core/storage/token_storage.dart';

import '../features/alerts/data/datasources/alert_remote_datasource.dart';
import '../features/alerts/data/repositories/alert_repository.dart';

import '../features/auth/data/datasources/auth_remote_datasource.dart';
import '../features/auth/data/repositories/auth_repository.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';

import '../features/compliance/data/datasources/non_conformity_remote_datasource.dart';
import '../features/compliance/data/repositories/non_conformity_repository.dart';

import '../features/cycles/data/datasources/cycle_remote_datasource.dart';
import '../features/cycles/data/repositories/cycle_repository.dart';

import '../features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import '../features/dashboard/data/repositories/dashboard_repository.dart';
import '../features/dashboard/presentation/cubit/dashboard_cubit.dart';

import '../features/history/data/datasources/audit_remote_datasource.dart';
import '../features/history/data/repositories/audit_repository.dart';

import '../features/identity/data/datasources/team_remote_datasource.dart';
import '../features/identity/data/repositories/team_repository.dart';

import '../features/labels/data/datasources/label_remote_datasource.dart';
import '../features/labels/data/datasources/label_usage_remote_datasource.dart';
import '../features/labels/data/repositories/label_repository.dart';
import '../features/labels/data/repositories/label_usage_repository.dart';

import '../features/patients/data/datasources/patient_remote_datasource.dart';
import '../features/patients/data/repositories/patient_repository.dart';

import '../features/scanner/presentation/bloc/scanner_bloc.dart';

import '../features/stock/data/datasources/stock_remote_datasource.dart';
import '../features/stock/data/repositories/stock_repository.dart';
import '../features/stock/presentation/cubit/stock_action_cubit.dart';

import '../features/tenancy/data/datasources/site_remote_datasource.dart';
import '../features/tenancy/data/repositories/site_repository.dart';

Future<void> registerFeatures(GetIt getIt) async {
  // Auth
  getIt.registerLazySingleton<AuthRemoteDatasource>(
    () => AuthRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(
      remote: getIt<AuthRemoteDatasource>(),
      tokenStorage: getIt<TokenStorage>(),
      sessionStore: getIt<SessionStore>(),
    ),
  );
  getIt.registerFactory<AuthBloc>(() => AuthBloc(getIt<AuthRepository>()));

  // Dashboard
  getIt.registerLazySingleton<DashboardRemoteDatasource>(
    () => DashboardRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<DashboardRepository>(
    () => DashboardRepository(getIt<DashboardRemoteDatasource>()),
  );
  getIt.registerFactory<DashboardCubit>(
    () => DashboardCubit(getIt<DashboardRepository>(), getIt<SessionStore>()),
  );

  // Labels
  getIt.registerLazySingleton<LabelRemoteDatasource>(
    () => LabelRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<LabelUsageRemoteDatasource>(
    () => LabelUsageRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<LabelRepository>(
    () => LabelRepository(getIt<LabelRemoteDatasource>()),
  );
  getIt.registerLazySingleton<LabelUsageRepository>(
    () => LabelUsageRepository(getIt<LabelUsageRemoteDatasource>()),
  );

  // Patients
  getIt.registerLazySingleton<PatientRemoteDatasource>(
    () => PatientRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<PatientRepository>(
    () => PatientRepository(getIt<PatientRemoteDatasource>()),
  );

  // Cycles
  getIt.registerLazySingleton<CycleRemoteDatasource>(
    () => CycleRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<CycleRepository>(
    () => CycleRepository(getIt<CycleRemoteDatasource>()),
  );

  // Scanner
  getIt.registerFactory<ScannerBloc>(
    () => ScannerBloc(getIt<LabelRepository>()),
  );

  // Alerts
  getIt.registerLazySingleton<AlertRemoteDatasource>(
    () => AlertRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<AlertRepository>(
    () => AlertRepository(getIt<AlertRemoteDatasource>()),
  );

  // Audit
  getIt.registerLazySingleton<AuditRemoteDatasource>(
    () => AuditRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<AuditRepository>(
    () => AuditRepository(getIt<AuditRemoteDatasource>()),
  );

  // Compliance
  getIt.registerLazySingleton<NonConformityRemoteDatasource>(
    () => NonConformityRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<NonConformityRepository>(
    () => NonConformityRepository(getIt<NonConformityRemoteDatasource>()),
  );

  // Team
  getIt.registerLazySingleton<TeamRemoteDatasource>(
    () => TeamRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<TeamRepository>(
    () => TeamRepository(getIt<TeamRemoteDatasource>()),
  );

  // Sites
  getIt.registerLazySingleton<SiteRemoteDatasource>(
    () => SiteRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<SiteRepository>(
    () => SiteRepository(getIt<SiteRemoteDatasource>()),
  );

  // Stock
  getIt.registerLazySingleton<StockRemoteDatasource>(
    () => StockRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<StockRepository>(
    () => StockRepository(getIt<StockRemoteDatasource>()),
  );
  getIt.registerFactory<StockActionCubit>(
    () => StockActionCubit(getIt<StockRepository>()),
  );
}
DART_EOF

cat > lib/app.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_status_cubit.dart';
import 'core/theme/app_theme.dart';
import 'di/di.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/cycles/data/repositories/cycle_repository.dart';
import 'features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'features/labels/data/repositories/label_repository.dart';
import 'features/labels/data/repositories/label_usage_repository.dart';
import 'features/patients/data/repositories/patient_repository.dart';
import 'features/stock/data/repositories/stock_repository.dart';

class SteryMedApp extends StatelessWidget {
  const SteryMedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<LabelRepository>(create: (_) => getIt()),
        RepositoryProvider<LabelUsageRepository>(create: (_) => getIt()),
        RepositoryProvider<PatientRepository>(create: (_) => getIt()),
        RepositoryProvider<CycleRepository>(create: (_) => getIt()),
        RepositoryProvider<StockRepository>(create: (_) => getIt()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(create: (_) => getIt()),
          BlocProvider<DashboardCubit>(create: (_) => getIt()),
          BlocProvider<SyncStatusCubit>.value(value: getIt()),
        ],
        child: const _AppView(),
      ),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final router = getIt<AppRouter>().router;
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      locale: const Locale(AppConstants.defaultLocale),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
DART_EOF

echo "   ✔ DI written"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 11 — Android manifest
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Phase 11 — Android manifest"

cat > android/app/src/main/AndroidManifest.xml << 'XML_EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-feature android:name="android.hardware.camera" android:required="false"/>

    <application
        android:label="SteryMed"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"/>
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
XML_EOF

echo "   ✔ manifest written"

# ─────────────────────────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅  All files deployed."
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "▶  Now running flutter clean + pub get + analyze ..."
echo ""

flutter clean
flutter pub get

echo ""
echo "▶  flutter analyze:"
echo ""
flutter analyze || true

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✔  Done. If analyze reported errors above, send them back."
echo "═══════════════════════════════════════════════════════════════"