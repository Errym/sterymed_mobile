// Phase 4 (C05): guided creation offers only what the server will accept: an
// active device and one of ITS active programs, sent together.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/cycles/data/models/cycle_data.dart';
import 'package:steriymed_mobile/features/cycles/data/models/device_data.dart';
import 'package:steriymed_mobile/features/cycles/data/models/device_program_data.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/cycle_repository.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/device_program_repository.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/device_repository.dart';
import 'package:steriymed_mobile/features/cycles/presentation/screens/cycle_create_screen.dart';

import '../helpers/pump_app.dart';

class _Cycles extends Mock implements CycleRepository {}

class _Devices extends Mock implements DeviceRepository {}

class _Programs extends Mock implements DeviceProgramRepository {}

class _Session extends Mock implements SessionStore {}

const _active = DeviceData(
  id: 'd-active',
  name: 'Autoclave A',
  status: 'active',
);
const _maintenance = DeviceData(
  id: 'd-maint',
  name: 'Autoclave B (maintenance)',
  status: 'maintenance',
);
const _live = DeviceProgramData(
  id: 'p-live',
  deviceId: 'd-active',
  name: 'Universel',
  temperatureCelsius: 134,
  plateauMinutes: 18,
  isActive: true,
);
const _retired = DeviceProgramData(
  id: 'p-old',
  deviceId: 'd-active',
  name: 'Ancien programme',
  temperatureCelsius: 121,
  plateauMinutes: 20,
  isActive: false,
);

void main() {
  late _Cycles cycles;
  late _Devices devices;
  late _Programs programs;

  setUp(() {
    cycles = _Cycles();
    devices = _Devices();
    programs = _Programs();
    final session = _Session();
    when(() => session.userName).thenReturn('Dr Test');
    when(
      () => devices.list(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async => [_maintenance, _active]);
    when(() => devices.invalidateCache()).thenReturn(null);
    when(() => devices.changes).thenAnswer((_) => const Stream<void>.empty());
    when(
      () => programs.list(any(), forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async => [_retired, _live]);
    final di = GetIt.instance;
    if (di.isRegistered<SessionStore>()) di.unregister<SessionStore>();
    if (di.isRegistered<DeviceRepository>()) di.unregister<DeviceRepository>();
    if (di.isRegistered<DeviceProgramRepository>()) {
      di.unregister<DeviceProgramRepository>();
    }
    GetIt.instance
      ..registerSingleton<SessionStore>(session)
      ..registerSingleton<DeviceRepository>(devices)
      ..registerSingleton<DeviceProgramRepository>(programs);
  });

  tearDown(() {
    GetIt.instance.unregister<SessionStore>();
    GetIt.instance.unregister<DeviceRepository>();
    GetIt.instance.unregister<DeviceProgramRepository>();
  });

  testWidgets('a device in maintenance and a retired program are not offered, '
      'and the chosen pair is sent together', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => cycles.create(any())).thenAnswer(
      (_) async => CycleData(
        id: 'c1',
        number: 'CT-1',
        status: 'created',
        deviceId: 'd-active',
        deviceName: 'Autoclave A',
        createdAt: DateTime(2026, 10, 1),
      ),
    );

    await pumpApp(
      tester,
      RepositoryProvider<CycleRepository>.value(
        value: cycles,
        child: const CycleCreateScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Only the active device is selected by default and the maintenance one
    // cannot be the choice.
    expect(find.textContaining('maintenance'), findsNothing);
    expect(find.textContaining('Ancien programme'), findsNothing);
    verify(() => programs.list('d-active', forceRefresh: true)).called(1);
    verifyNever(
      () => programs.list('d-maint', forceRefresh: any(named: 'forceRefresh')),
    );

    await tester.tap(find.text('Initialiser & Charger les Sachets'));
    await tester.pumpAndSettle();

    final sent =
        verify(() => cycles.create(captureAny())).captured.single
            as Map<String, dynamic>;
    expect(sent['device_id'], 'd-active');
    expect(sent['device_program_id'], 'p-live');
  });
}
