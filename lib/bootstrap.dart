import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/bootstrap/stock_seed_check.dart';
import 'core/config/env.dart';
import 'core/config/build_info.dart';
import 'core/crash/crash_reporter.dart';
import 'core/push/push_service.dart';
import 'core/security/inactivity_lock.dart';
import 'core/security/privacy_screen.dart';
import 'core/storage/session_store.dart';
import 'core/sync/sync_status_cubit.dart';
import 'di/di.dart';
import 'features/stock/data/repositories/stock_repository.dart';

Future<void> bootstrap(Widget Function() appBuilder) async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertSecureTransportInProduction();
  try {
    await Hive.initFlutter();
    await initDi();
    await getIt<SessionStore>().load();
  } catch (_) {
    // Local storage could not be opened (damaged files, lost key). Show a
    // screen that says so; nothing is wiped, and a restart retries.
    runApp(const StartupProblemApp());
    return;
  }
  runApp(appBuilder());
  getIt<InactivityLock>().attach();
  unawaited(PrivacyScreen.apply());
  unawaited(BuildInfo.initialize().catchError((Object _) {}));
  unawaited(getIt<CrashReporter>().init().catchError((Object _) {}));
  unawaited(getIt<SyncStatusCubit>().start());
  // Notifications follow the signed-in person; nothing starts without their opt-in.
  getIt<PushService>().attach();
  unawaited(
    checkStockSeedStatus(
      session: getIt<SessionStore>(),
      stockRepository: getIt<StockRepository>(),
      crashReporter: getIt<CrashReporter>(),
    ),
  );
}

/// Shown instead of a blank crash when the device's local storage cannot be
/// opened at launch. It never deletes anything: the data stays on the device
/// for support to recover.
class StartupProblemApp extends StatelessWidget {
  const StartupProblemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storage_outlined, size: 56),
                  SizedBox(height: 16),
                  Text(
                    "Le stockage de l'appareil demande une vérification",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Vos données n'ont pas été supprimées. Fermez puis "
                    "relancez l'application. Si le message revient, "
                    'contactez le responsable du cabinet sans réinitialiser '
                    'cet appareil.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
