import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/storage/session_store.dart';
import 'core/storage/key_value_store.dart';
import 'core/storage/outbox/outbox_store.dart';
import 'core/sync/sync_status_cubit.dart';
import 'core/theme/app_theme.dart';
import 'di/di.dart';
import 'features/alerts/data/repositories/alert_repository.dart';
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
        RepositoryProvider<AlertRepository>(create: (_) => getIt()),
        RepositoryProvider<LabelRepository>(create: (_) => getIt()),
        RepositoryProvider<LabelUsageRepository>(create: (_) => getIt()),
        RepositoryProvider<PatientRepository>(create: (_) => getIt()),
        RepositoryProvider<CycleRepository>(create: (_) => getIt()),
        RepositoryProvider<StockRepository>(create: (_) => getIt()),
      ],
      child: StreamBuilder<int>(
        stream: getIt<SessionStore>().changes,
        builder: (context, snapshot) => MultiBlocProvider(
          key: ValueKey(getIt<SessionStore>().generation),
          providers: [
            BlocProvider<AuthBloc>.value(value: getIt()),
            BlocProvider<DashboardCubit>(create: (_) => getIt()),
            BlocProvider<SyncStatusCubit>.value(value: getIt()),
          ],
          child: const _AppView(),
        ),
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
      builder: (context, child) {
        final drafts = getIt<KeyValueStore>();
        final queue = getIt<OutboxStore>();
        if (!drafts.recoveryRequired &&
            !queue.recoveryRequired &&
            drafts.quarantineCount == 0 &&
            queue.quarantineCount == 0) {
          return child!;
        }
        return Column(
          children: [
            Material(
              color: Colors.amber.shade100,
              child: const SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Des données locales sont conservées à part et nécessitent une vérification. Contactez le responsable du cabinet avant de réinitialiser cet appareil.',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                ),
              ),
            ),
            Expanded(child: child!),
          ],
        );
      },
      routerConfig: router,
    );
  }
}
