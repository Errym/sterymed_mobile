// =============================================================================
// SteryMed — Feature DI Registration
// Rebuilt against actual backend endpoints (see docs/backend_routes.json).
//
// NOTE:
//   - Sites:   GET only (no POST /v1/sites)
//   - Locations: read-only (no POST /v1/sites/{id}/locations)
//   - Batches: read-only (no POST /v1/batches; created via Goods Receipt)
//   - The corresponding DataSources/Repositories are registered but
//     their `create` methods must not be called.
// =============================================================================

import 'package:get_it/get_it.dart';

import '../core/cache/cache.dart';
import '../core/network/dio_client.dart';
import '../core/storage/session_store.dart';
import '../core/storage/token_storage.dart';

// ── Auth ────────────────────────────────────────────────────────────────────
import '../features/auth/data/datasources/auth_remote_datasource.dart';
import '../features/auth/data/repositories/auth_repository.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';

// ── Dashboard ───────────────────────────────────────────────────────────────
import '../features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import '../features/dashboard/data/repositories/dashboard_repository.dart';
import '../features/dashboard/presentation/cubit/dashboard_cubit.dart';

// ── Alerts ──────────────────────────────────────────────────────────────────
import '../features/alerts/data/datasources/alert_remote_datasource.dart';
import '../features/alerts/data/repositories/alert_repository.dart';
import '../features/alerts/presentation/bloc/alert_list_bloc.dart';

// ── Catalog (products) ──────────────────────────────────────────────────────
import '../features/catalog/data/datasources/product_remote_datasource.dart';
import '../features/catalog/data/repositories/product_repository.dart';
import '../features/catalog/presentation/bloc/product_list_bloc.dart';

// ── Compliance (non-conformities) ───────────────────────────────────────────
import '../features/compliance/data/datasources/non_conformity_remote_datasource.dart';
import '../features/compliance/data/repositories/non_conformity_repository.dart';
import '../features/compliance/presentation/bloc/non_conformity_list_bloc.dart';

// ── Cycles (sterilization) ──────────────────────────────────────────────────
import '../features/cycles/data/datasources/cycle_remote_datasource.dart';
import '../features/cycles/data/datasources/device_remote_datasource.dart';
import '../features/cycles/data/repositories/cycle_repository.dart';
import '../features/cycles/data/repositories/device_repository.dart';
import '../features/cycles/presentation/bloc/cycle_list_bloc.dart';
import '../features/cycles/presentation/bloc/cycle_detail_bloc.dart';
import '../features/cycles/presentation/bloc/cycle_transition_bloc.dart';
import '../features/cycles/presentation/bloc/cycle_create_bloc.dart';
import '../features/cycles/presentation/bloc/cycle_items_bloc.dart';
import '../features/cycles/presentation/bloc/cycle_control_tests_bloc.dart';
import '../features/cycles/presentation/bloc/cycle_attachments_bloc.dart';
import '../features/cycles/presentation/bloc/cycle_release_bloc.dart';

// ── Devices (list screen) ───────────────────────────────────────────────────
import '../features/devices/data/datasources/device_detail_datasource.dart';
import '../features/devices/data/repositories/device_detail_repository.dart';

// ── DLU rules ───────────────────────────────────────────────────────────────
import '../features/dlu/data/datasources/dlu_remote_datasource.dart';
import '../features/dlu/data/repositories/dlu_repository.dart';

// ── History / audit ─────────────────────────────────────────────────────────
import '../features/history/data/datasources/audit_remote_datasource.dart';
import '../features/history/data/repositories/audit_repository.dart';
import '../features/history/presentation/bloc/audit_list_bloc.dart';

// ── Identity (team) ─────────────────────────────────────────────────────────
import '../features/identity/data/datasources/team_remote_datasource.dart';
import '../features/identity/data/repositories/team_repository.dart';
import '../features/identity/presentation/bloc/team_list_bloc.dart';

// ── Labels ──────────────────────────────────────────────────────────────────
import '../features/labels/data/datasources/label_remote_datasource.dart';
import '../features/labels/data/datasources/label_usage_remote_datasource.dart';
import '../features/labels/data/repositories/label_repository.dart';
import '../features/labels/data/repositories/label_usage_repository.dart';

// ── Patients ────────────────────────────────────────────────────────────────
import '../features/patients/data/datasources/patient_remote_datasource.dart';
import '../features/patients/data/repositories/patient_repository.dart';
import '../features/patients/presentation/bloc/patient_list_bloc.dart';
import '../features/patients/presentation/bloc/patient_search_bloc.dart';

// ── Purchases ───────────────────────────────────────────────────────────────
import '../features/purchases/data/datasources/purchase_remote_datasource.dart';
import '../features/purchases/data/repositories/purchase_repository.dart';
import '../features/purchases/presentation/bloc/purchase_order_list_bloc.dart';

// ── Reporting ───────────────────────────────────────────────────────────────
import '../features/reporting/data/datasources/export_remote_datasource.dart';
import '../features/reporting/data/repositories/export_repository.dart';

// ── Scanner ─────────────────────────────────────────────────────────────────
import '../features/scanner/presentation/bloc/scanner_bloc.dart';

// ── Sites (READ-ONLY) ───────────────────────────────────────────────────────
import '../features/sites/data/datasources/site_remote_datasource.dart';
import '../features/sites/data/repositories/site_repository.dart';
import '../features/sites/presentation/bloc/site_list_bloc.dart';

// ── Stock ───────────────────────────────────────────────────────────────────
import '../features/stock/data/datasources/stock_remote_datasource.dart';
import '../features/stock/data/repositories/stock_repository.dart';
import '../features/stock/presentation/bloc/stock_level_list_bloc.dart';
import '../features/stock/presentation/bloc/stock_issue_bloc.dart';
import '../features/stock/presentation/bloc/stock_adjust_bloc.dart';
import '../features/stock/presentation/bloc/stock_transfer_bloc.dart';
import '../features/stock/presentation/cubit/stock_action_cubit.dart';

// ── Suppliers ───────────────────────────────────────────────────────────────
import '../features/suppliers/data/datasources/supplier_remote_datasource.dart';
import '../features/suppliers/data/repositories/supplier_repository.dart';
import '../features/suppliers/presentation/bloc/supplier_list_bloc.dart';


Future<void> registerFeatures(GetIt getIt) async {
  // ─────────────────────────────────────────────────────────────────────────
  // Auth
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<AuthRemoteDatasource>(
    () => AuthRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<AuthRepository>(() => AuthRepository(
        remote: getIt<AuthRemoteDatasource>(),
        tokenStorage: getIt<TokenStorage>(),
        sessionStore: getIt<SessionStore>(),
      ));
  getIt.registerFactory<AuthBloc>(() => AuthBloc(getIt<AuthRepository>()));

  // ─────────────────────────────────────────────────────────────────────────
  // Dashboard
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<DashboardRemoteDatasource>(
    () => DashboardRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<DashboardRepository>(() => DashboardRepository(
        getIt<DashboardRemoteDatasource>(),
        getIt<AppCache>(),
      ));
  getIt.registerFactory<DashboardCubit>(
    () => DashboardCubit(getIt<DashboardRepository>(), getIt<SessionStore>()),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Labels
  // ─────────────────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────────────────
  // Patients
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<PatientRemoteDatasource>(
    () => PatientRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<PatientRepository>(() => PatientRepository(
        getIt<PatientRemoteDatasource>(),
        getIt<AppCache>(),
      ));
  getIt.registerFactory<PatientListBloc>(
    () => PatientListBloc(getIt<PatientRepository>()),
  );
  getIt.registerFactory<PatientSearchBloc>(
    () => PatientSearchBloc(getIt<PatientRepository>()),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Products
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<ProductRemoteDatasource>(
    () => ProductRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<ProductRepository>(() => ProductRepository(
        getIt<ProductRemoteDatasource>(),
        getIt<AppCache>(),
      ));
  getIt.registerFactory<ProductListBloc>(
    () => ProductListBloc(getIt<ProductRepository>()),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Suppliers
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<SupplierRemoteDatasource>(
    () => SupplierRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<SupplierRepository>(() => SupplierRepository(
        getIt<SupplierRemoteDatasource>(),
        getIt<AppCache>(),
      ));
  getIt.registerFactory<SupplierListBloc>(
    () => SupplierListBloc(getIt<SupplierRepository>()),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Cycles
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<CycleRemoteDatasource>(
    () => CycleRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<CycleRepository>(() => CycleRepository(
        getIt<CycleRemoteDatasource>(),
        getIt<AppCache>(),
      ));
  getIt.registerFactory<CycleListBloc>(
    () => CycleListBloc(getIt<CycleRepository>()),
  );
  getIt.registerFactory<CycleDetailBloc>(
    () => CycleDetailBloc(getIt<CycleRepository>()),
  );
  getIt.registerFactory<CycleTransitionBloc>(
    () => CycleTransitionBloc(getIt<CycleRepository>()),
  );
  getIt.registerFactory<CycleCreateBloc>(
    () => CycleCreateBloc(getIt<CycleRepository>()),
  );
  getIt.registerFactory<CycleReleaseBloc>(
    () => CycleReleaseBloc(getIt<CycleRepository>()),
  );
  getIt.registerFactoryParam<CycleItemsBloc, String, void>(
    (cycleId, _) => CycleItemsBloc(getIt<CycleRepository>(), cycleId),
  );
  getIt.registerFactoryParam<CycleControlTestsBloc, String, void>(
    (cycleId, _) => CycleControlTestsBloc(getIt<CycleRepository>(), cycleId),
  );
  getIt.registerFactoryParam<CycleAttachmentsBloc, String, void>(
    (cycleId, _) => CycleAttachmentsBloc(getIt<CycleRepository>(), cycleId),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Devices
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<DeviceRemoteDatasource>(
    () => DeviceRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<DeviceRepository>(() => DeviceRepository(
        getIt<DeviceRemoteDatasource>(),
        getIt<AppCache>(),
      ));
  getIt.registerLazySingleton<DeviceDetailDatasource>(
    () => DeviceDetailDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<DeviceDetailRepository>(
    () => DeviceDetailRepository(
      getIt<DeviceDetailDatasource>(),
      getIt<AppCache>(),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Scanner
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerFactory<ScannerBloc>(
    () => ScannerBloc(getIt<LabelRepository>()),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Alerts
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<AlertRemoteDatasource>(
    () => AlertRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<AlertRepository>(() => AlertRepository(
        getIt<AlertRemoteDatasource>(),
        getIt<AppCache>(),
      ));
  getIt.registerFactory<AlertListBloc>(
    () => AlertListBloc(getIt<AlertRepository>()),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Audit
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<AuditRemoteDatasource>(
    () => AuditRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<AuditRepository>(() => AuditRepository(
        getIt<AuditRemoteDatasource>(),
        getIt<AppCache>(),
      ));
  getIt.registerFactory<AuditListBloc>(
    () => AuditListBloc(getIt<AuditRepository>()),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Non-conformities
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<NonConformityRemoteDatasource>(
    () => NonConformityRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<NonConformityRepository>(
    () => NonConformityRepository(
      getIt<NonConformityRemoteDatasource>(),
      getIt<AppCache>(),
    ),
  );
  getIt.registerFactory<NonConformityListBloc>(
    () => NonConformityListBloc(getIt<NonConformityRepository>()),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Team
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<TeamRemoteDatasource>(
    () => TeamRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<TeamRepository>(() => TeamRepository(
        getIt<TeamRemoteDatasource>(),
        getIt<AppCache>(),
      ));
  getIt.registerFactory<TeamListBloc>(
    () => TeamListBloc(getIt<TeamRepository>()),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Sites (READ-ONLY — no POST endpoint exists)
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<SiteRemoteDatasource>(
    () => SiteRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<SiteRepository>(() => SiteRepository(
        getIt<SiteRemoteDatasource>(),
        getIt<AppCache>(),
      ));
  getIt.registerFactory<SiteListBloc>(
    () => SiteListBloc(getIt<SiteRepository>()),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // DLU rules
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<DluRemoteDatasource>(
    () => DluRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<DluRepository>(() => DluRepository(
        getIt<DluRemoteDatasource>(),
        getIt<AppCache>(),
      ));

  // ─────────────────────────────────────────────────────────────────────────
  // Purchases
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<PurchaseRemoteDatasource>(
    () => PurchaseRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<PurchaseRepository>(() => PurchaseRepository(
        getIt<PurchaseRemoteDatasource>(),
        getIt<AppCache>(),
      ));
  getIt.registerFactory<PurchaseOrderListBloc>(
    () => PurchaseOrderListBloc(getIt<PurchaseRepository>()),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Reporting
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<ExportRemoteDatasource>(
    () => ExportRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<ExportRepository>(() => ExportRepository(
        getIt<ExportRemoteDatasource>(),
        getIt<AppCache>(),
      ));

  // ─────────────────────────────────────────────────────────────────────────
  // Stock
  // ─────────────────────────────────────────────────────────────────────────
  getIt.registerLazySingleton<StockRemoteDatasource>(
    () => StockRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<StockRepository>(() => StockRepository(
        getIt<StockRemoteDatasource>(),
        getIt<AppCache>(),
      ));
  getIt.registerFactory<StockLevelListBloc>(
    () => StockLevelListBloc(getIt<StockRepository>()),
  );
  getIt.registerFactory<StockIssueBloc>(
    () => StockIssueBloc(getIt<StockRepository>()),
  );
  getIt.registerFactory<StockAdjustBloc>(
    () => StockAdjustBloc(getIt<StockRepository>()),
  );
  getIt.registerFactory<StockTransferBloc>(
    () => StockTransferBloc(getIt<StockRepository>()),
  );
  getIt.registerFactory<StockActionCubit>(
    () => StockActionCubit(getIt<StockRepository>()),
  );
}
