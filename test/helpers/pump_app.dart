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

/// flutter_test's default screen is 800x600 logical pixels: wider than a phone
/// and far too short for a real screen, so anything below the first 600 px is
/// never built and tests would have to scroll for every button. Unless a test
/// chose its own size, use a tall phone-width screen (a test that sets
/// `tester.view.physicalSize` itself is left alone).
void _useTallDefaultScreen(WidgetTester tester) {
  const defaultPhysical = Size(2400, 1800);
  if (tester.view.physicalSize != defaultPhysical ||
      tester.view.devicePixelRatio != 3.0) {
    return;
  }
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

/// Pumps a widget inside a standard MaterialApp with French localization.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('fr'),
  SyncStatusCubit? syncStatusCubit,
}) async {
  _useTallDefaultScreen(tester);
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
