import 'package:get_it/get_it.dart';

import '../core/network/dio_client.dart';
import '../core/storage/session_store.dart';
import '../core/storage/token_storage.dart';
import '../features/auth/data/datasources/auth_remote_datasource.dart';
import '../features/auth/data/repositories/auth_repository.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/cycles/data/datasources/cycle_remote_datasource.dart';
import '../features/cycles/data/repositories/cycle_repository.dart';
import '../features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import '../features/dashboard/data/repositories/dashboard_repository.dart';
import '../features/dashboard/presentation/cubit/dashboard_cubit.dart';
import '../features/labels/data/datasources/label_remote_datasource.dart';
import '../features/labels/data/datasources/label_usage_remote_datasource.dart';
import '../features/labels/data/repositories/label_repository.dart';
import '../features/labels/data/repositories/label_usage_repository.dart';
import '../features/patients/data/datasources/patient_remote_datasource.dart';
import '../features/patients/data/repositories/patient_repository.dart';
import '../features/scanner/presentation/bloc/scanner_bloc.dart';

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

  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(getIt<AuthRepository>()),
  );

  // ═══════════════════════════════════════════════════════════════
  // DASHBOARD
  // ═══════════════════════════════════════════════════════════════
  getIt.registerLazySingleton<DashboardRemoteDatasource>(
    () => const DashboardRemoteDatasource(),
  );

  getIt.registerLazySingleton<DashboardRepository>(
    () => DashboardRepository(getIt<DashboardRemoteDatasource>()),
  );

  getIt.registerFactory<DashboardCubit>(
    () => DashboardCubit(getIt<DashboardRepository>()),
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

  // ═══════════════════════════════════════════════════════════════
  // SCANNER
  // ═══════════════════════════════════════════════════════════════
  getIt.registerFactory<ScannerBloc>(
    () => ScannerBloc(),
  );
}
