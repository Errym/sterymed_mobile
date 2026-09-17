import 'package:get_it/get_it.dart';

import '../core/network/dio_client.dart';
import '../core/storage/session_store.dart';
import '../core/storage/token_storage.dart';

// ── Alerts ────────────────────────────────────────────────────────
import '../features/alerts/data/datasources/alert_remote_datasource.dart';
import '../features/alerts/data/repositories/alert_repository.dart';

// ── Auth ──────────────────────────────────────────────────────────
import '../features/auth/data/datasources/auth_remote_datasource.dart';
import '../features/auth/data/repositories/auth_repository.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';

// ── Compliance ────────────────────────────────────────────────────
import '../features/compliance/data/datasources/non_conformity_remote_datasource.dart';
import '../features/compliance/data/repositories/non_conformity_repository.dart';

// ── Cycles ────────────────────────────────────────────────────────
import '../features/cycles/data/datasources/cycle_remote_datasource.dart';
import '../features/cycles/data/datasources/device_remote_datasource.dart';
import '../features/cycles/data/repositories/cycle_repository.dart';
import '../features/cycles/data/repositories/device_repository.dart';

// ── Dashboard ─────────────────────────────────────────────────────
import '../features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import '../features/dashboard/data/repositories/dashboard_repository.dart';
import '../features/dashboard/presentation/cubit/dashboard_cubit.dart';

// ── History / Audit ───────────────────────────────────────────────
import '../features/history/data/datasources/audit_remote_datasource.dart';
import '../features/history/data/repositories/audit_repository.dart';

// ── Identity / Team ───────────────────────────────────────────────
import '../features/identity/data/datasources/team_remote_datasource.dart';
import '../features/identity/data/repositories/team_repository.dart';

// ── Labels ────────────────────────────────────────────────────────
import '../features/labels/data/datasources/label_remote_datasource.dart';
import '../features/labels/data/datasources/label_usage_remote_datasource.dart';
import '../features/labels/data/repositories/label_repository.dart';
import '../features/labels/data/repositories/label_usage_repository.dart';

// ── Patients ──────────────────────────────────────────────────────
import '../features/patients/data/datasources/patient_remote_datasource.dart';
import '../features/patients/data/repositories/patient_repository.dart';

// ── Scanner ───────────────────────────────────────────────────────
import '../features/scanner/presentation/bloc/scanner_bloc.dart';

// ── Stock ─────────────────────────────────────────────────────────
import '../features/stock/data/datasources/stock_remote_datasource.dart';
import '../features/stock/data/repositories/stock_repository.dart';
import '../features/stock/presentation/cubit/stock_action_cubit.dart';

// ── Tenancy / Sites ───────────────────────────────────────────────
import '../features/tenancy/data/datasources/site_remote_datasource.dart';
import '../features/tenancy/data/repositories/site_repository.dart';

Future<void> registerFeatures(GetIt getIt) async {
  // ═══════════════════════════════════════════════════════════════
  // AUTH
  // ═══════════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════════
  // DASHBOARD
  // ═══════════════════════════════════════════════════════════════
  getIt.registerLazySingleton<DashboardRemoteDatasource>(
    () => DashboardRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<DashboardRepository>(
    () => DashboardRepository(getIt<DashboardRemoteDatasource>()),
  );
  getIt.registerFactory<DashboardCubit>(
    () => DashboardCubit(getIt<DashboardRepository>(), getIt<SessionStore>()),
  );

  // ═══════════════════════════════════════════════════════════════
  // LABELS
  // ═══════════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════════
  // PATIENTS
  // ═══════════════════════════════════════════════════════════════
  getIt.registerLazySingleton<PatientRemoteDatasource>(
    () => PatientRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<PatientRepository>(
    () => PatientRepository(getIt<PatientRemoteDatasource>()),
  );

  // ═══════════════════════════════════════════════════════════════
  // CYCLES
  // ═══════════════════════════════════════════════════════════════
  getIt.registerLazySingleton<CycleRemoteDatasource>(
    () => CycleRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<CycleRepository>(
    () => CycleRepository(getIt<CycleRemoteDatasource>()),
  );

  // ── Devices (for cycle creation) ───────────────────────────────
  getIt.registerLazySingleton<DeviceRemoteDatasource>(
    () => DeviceRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<DeviceRepository>(
    () => DeviceRepository(getIt<DeviceRemoteDatasource>()),
  );

  // ═══════════════════════════════════════════════════════════════
  // SCANNER
  // ═══════════════════════════════════════════════════════════════
  getIt.registerFactory<ScannerBloc>(
    () => ScannerBloc(getIt<LabelRepository>()),
  );

  // ═══════════════════════════════════════════════════════════════
  // ALERTS
  // ═══════════════════════════════════════════════════════════════
  getIt.registerLazySingleton<AlertRemoteDatasource>(
    () => AlertRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<AlertRepository>(
    () => AlertRepository(getIt<AlertRemoteDatasource>()),
  );

  // ═══════════════════════════════════════════════════════════════
  // AUDIT
  // ═══════════════════════════════════════════════════════════════
  getIt.registerLazySingleton<AuditRemoteDatasource>(
    () => AuditRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<AuditRepository>(
    () => AuditRepository(getIt<AuditRemoteDatasource>()),
  );

  // ═══════════════════════════════════════════════════════════════
  // COMPLIANCE
  // ═══════════════════════════════════════════════════════════════
  getIt.registerLazySingleton<NonConformityRemoteDatasource>(
    () => NonConformityRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<NonConformityRepository>(
    () => NonConformityRepository(getIt<NonConformityRemoteDatasource>()),
  );

  // ═══════════════════════════════════════════════════════════════
  // TEAM
  // ═══════════════════════════════════════════════════════════════
  getIt.registerLazySingleton<TeamRemoteDatasource>(
    () => TeamRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<TeamRepository>(
    () => TeamRepository(getIt<TeamRemoteDatasource>()),
  );

  // ═══════════════════════════════════════════════════════════════
  // SITES
  // ═══════════════════════════════════════════════════════════════
  getIt.registerLazySingleton<SiteRemoteDatasource>(
    () => SiteRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<SiteRepository>(
    () => SiteRepository(getIt<SiteRemoteDatasource>()),
  );

  // ═══════════════════════════════════════════════════════════════
  // STOCK
  // ═══════════════════════════════════════════════════════════════
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
