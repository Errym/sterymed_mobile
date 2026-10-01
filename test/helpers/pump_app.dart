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
