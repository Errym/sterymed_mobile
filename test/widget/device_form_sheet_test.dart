// Device editing: a failed read must never leave blank, editable fields (a save
// would erase the real values), and emptied optional fields must be sent as an
// explicit clear.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/device_repository.dart';
import 'package:steriymed_mobile/features/devices/data/datasources/device_detail_datasource.dart';
import 'package:steriymed_mobile/features/devices/data/models/device_detail.dart';
import 'package:steriymed_mobile/features/devices/data/repositories/device_detail_repository.dart';
import 'package:steriymed_mobile/features/devices/presentation/widgets/device_form_sheet.dart';
import 'package:steriymed_mobile/features/sites/data/repositories/site_repository.dart';

import '../helpers/pump_app.dart';

class _MockDevices extends Mock implements DeviceDetailRepository {}

class _MockSites extends Mock implements SiteRepository {}

class _MockPicker extends Mock implements DeviceRepository {}

const _device = DeviceDetail(
  id: 'd1',
  name: 'Melag Vacuklav',
  serialNumber: 'MEL-001',
  manufacturer: 'Melag',
  model: '40B+',
  status: 'active',
  siteId: 's1',
  notes: 'Révision en mars',
);

class _Capture implements HttpClientAdapter {
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode({'id': 'd1', 'name': 'x'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'update sends manufacturer, model and notes as explicit clears',
    () async {
      final adapter = _Capture();
      final datasource = DeviceDetailDatasource(
        Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api'))
          ..httpClientAdapter = adapter,
      );

      await datasource.update(
        id: 'd1',
        name: 'Melag',
        serialNumber: 'MEL-001',
        status: 'active',
        manufacturer: null,
        model: null,
        notes: null,
      );

      final body = adapter.last!.data as Map;
      for (final key in ['manufacturer', 'model', 'notes']) {
        expect(body.containsKey(key), isTrue, reason: key);
        expect(body[key], isNull, reason: key);
      }
      expect(body['name'], 'Melag');
    },
  );

  group('DeviceFormSheet', () {
    late _MockDevices devices;
    late _MockSites sites;
    late _MockPicker picker;

    setUp(() {
      devices = _MockDevices();
      sites = _MockSites();
      picker = _MockPicker();
      when(() => picker.invalidateCache()).thenReturn(null);
      when(
        () => devices.update(
          id: any(named: 'id'),
          name: any(named: 'name'),
          serialNumber: any(named: 'serialNumber'),
          status: any(named: 'status'),
          manufacturer: any(named: 'manufacturer'),
          model: any(named: 'model'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => _device);

      final di = GetIt.instance;
      if (di.isRegistered<DeviceDetailRepository>()) {
        di.unregister<DeviceDetailRepository>();
      }
      if (di.isRegistered<SiteRepository>()) {
        di.unregister<SiteRepository>();
      }
      if (di.isRegistered<DeviceRepository>()) {
        di.unregister<DeviceRepository>();
      }
      di
        ..registerSingleton<DeviceDetailRepository>(devices)
        ..registerSingleton<SiteRepository>(sites)
        ..registerSingleton<DeviceRepository>(picker);
    });

    tearDown(() {
      final di = GetIt.instance;
      di.unregister<DeviceDetailRepository>();
      di.unregister<SiteRepository>();
      di.unregister<DeviceRepository>();
    });

    Future<void> open(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpApp(
        tester,
        const Scaffold(body: DeviceFormSheet(existingId: 'd1')),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('loads the real values into the form', (tester) async {
      when(() => devices.show('d1')).thenAnswer((_) async => _device);

      await open(tester);

      expect(find.text('Melag Vacuklav'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == 'MEL-001',
        ),
        findsOneWidget,
      );
      expect(find.text('Révision en mars'), findsOneWidget);
      // Editing never needs the list of sites.
      verifyNever(() => sites.list(forceRefresh: any(named: 'forceRefresh')));
    });

    testWidgets(
      'a failed read shows an error and retry, NOT blank editable fields',
      (tester) async {
        when(() => devices.show('d1')).thenThrow(Exception('réseau'));

        await open(tester);

        expect(
          find.textContaining('Impossible de charger cet appareil'),
          findsOneWidget,
        );
        expect(find.text('Rien n\'a été modifié.'), findsNothing);
        expect(find.byType(TextFormField), findsNothing);
        expect(find.text('Réessayer'), findsOneWidget);
        expect(find.text('Enregistrer les modifications'), findsNothing);
        verifyNever(
          () => devices.update(
            id: any(named: 'id'),
            name: any(named: 'name'),
            serialNumber: any(named: 'serialNumber'),
            status: any(named: 'status'),
            manufacturer: any(named: 'manufacturer'),
            model: any(named: 'model'),
            notes: any(named: 'notes'),
          ),
        );
      },
    );

    testWidgets('retry loads the form once the read works', (tester) async {
      var calls = 0;
      when(() => devices.show('d1')).thenAnswer((_) async {
        if (++calls == 1) throw Exception('réseau');
        return _device;
      });

      await open(tester);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsWidgets);
      expect(find.text('Melag Vacuklav'), findsOneWidget);
    });

    testWidgets('emptying manufacturer, model and notes clears them on save', (
      tester,
    ) async {
      when(() => devices.show('d1')).thenAnswer((_) async => _device);
      await open(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Melag'), '');
      await tester.enterText(find.widgetWithText(TextFormField, '40B+'), '');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Révision en mars'),
        '',
      );
      await tester.tap(find.text('Enregistrer les modifications'));
      await tester.pumpAndSettle();

      final call = verify(
        () => devices.update(
          id: 'd1',
          name: any(named: 'name'),
          serialNumber: any(named: 'serialNumber'),
          status: any(named: 'status'),
          manufacturer: captureAny(named: 'manufacturer'),
          model: captureAny(named: 'model'),
          notes: captureAny(named: 'notes'),
        ),
      );
      expect(call.captured, [null, null, null]);
    });
  });
}
