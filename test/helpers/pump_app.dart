import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/sync/sync_status.dart';
import 'package:steriymed_mobile/core/sync/sync_status_cubit.dart';

import '../mocks/mock_sync_status_cubit.dart';

/// Pumps a complete app, including router-based apps, with the global sync
/// provider that SteryMedApp supplies in production. Tests can pass their own
/// cubit or override it with a provider closer to the screen under test.
Future<void> pumpAppWidget(
  WidgetTester tester,
  Widget app, {
  SyncStatusCubit? syncStatusCubit,
}) async {
  final cubit = syncStatusCubit ?? MockSyncStatusCubit();
  if (syncStatusCubit == null) {
    whenListen(
      cubit,
      const Stream<SyncStatus>.empty(),
      initialState: const SyncStatus(),
    );
    addTearDown(cubit.close);
  }

  await tester.pumpWidget(
    BlocProvider<SyncStatusCubit>.value(value: cubit, child: app),
  );
}

/// Pumps a widget inside a standard MaterialApp with French localization.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('fr'),
  SyncStatusCubit? syncStatusCubit,
}) async {
  await pumpAppWidget(
    tester,
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
    syncStatusCubit: syncStatusCubit,
  );
}

/// Like [pumpApp] on a tall phone-width screen, for tests of screens whose
/// buttons sit far down a long list. Opt-in per test file: changing the default
/// size for every test changes what other tests can see and tap.
Future<void> pumpAppTall(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('fr'),
  SyncStatusCubit? syncStatusCubit,
}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    child,
    locale: locale,
    syncStatusCubit: syncStatusCubit,
  );
}
