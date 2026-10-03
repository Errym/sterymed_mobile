// The creation forms behave: the preview follows what is typed, presets fill
// the fields, bad input is refused before anything is sent, and the new
// product-family shortcut really creates a family.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/features/catalog/data/models/product_category_data.dart';
import 'package:steriymed_mobile/features/catalog/data/repositories/product_category_repository.dart';
import 'package:steriymed_mobile/features/catalog/data/repositories/product_repository.dart';
import 'package:steriymed_mobile/features/catalog/presentation/bloc/product_list_bloc.dart';
import 'package:steriymed_mobile/features/catalog/presentation/widgets/product_form_sheet.dart';
import 'package:steriymed_mobile/features/devices/presentation/widgets/maintenance_record_form_sheet.dart';
import 'package:steriymed_mobile/features/devices/presentation/widgets/programme_form_sheet.dart';
import 'package:steriymed_mobile/features/stock/data/models/stock_option.dart';
import 'package:steriymed_mobile/features/stock/data/repositories/stock_repository.dart';
import 'package:steriymed_mobile/features/suppliers/presentation/widgets/supplier_form_sheet.dart';

import '../helpers/pump_app.dart';

class _Categories extends Mock implements ProductCategoryRepository {}

class _Products extends Mock implements ProductRepository {}

class _Stock extends Mock implements StockRepository {}

void _register<T extends Object>(T v) {
  if (GetIt.I.isRegistered<T>()) GetIt.I.unregister<T>();
  GetIt.I.registerSingleton<T>(v);
}

void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  tearDown(() => GetIt.I.reset());

  group('programme form', () {
    testWidgets('a preset fills the parameters and the preview follows',
        (tester) async {
      tall(tester);
      await pumpApp(
        tester,
        const Scaffold(body: ProgrammeFormSheet(deviceId: 'd1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nom du programme'), findsOneWidget,
          reason: 'the preview starts with a placeholder');

      await tester.tap(find.byKey(const ValueKey('preset_134_18')));
      await tester.pumpAndSettle();

      final temp = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, '134'),
      );
      expect(temp.controller!.text, '134');
      expect(find.text('18 min'), findsWidgets);
      expect(find.text('134 °C'), findsWidgets);
      // A name is proposed only because the field was empty.
      expect(find.textContaining('Prions 134°C'), findsWidgets);
    });

    testWidgets('a preset never overwrites a name already typed',
        (tester) async {
      tall(tester);
      await pumpApp(
        tester,
        const Scaffold(body: ProgrammeFormSheet(deviceId: 'd1')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ex : Instrument 134C 4min').first,
        'Mon programme',
      );
      await tester.tap(find.byKey(const ValueKey('preset_121_20')));
      await tester.pumpAndSettle();
      expect(find.text('Mon programme'), findsWidgets);
      final name = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(name.controller!.text, 'Mon programme',
          reason: 'the typed name is kept');
    });

    testWidgets('out-of-range temperature and duration are refused',
        (tester) async {
      tall(tester);
      await pumpApp(
        tester,
        const Scaffold(body: ProgrammeFormSheet(deviceId: 'd1')),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Test');
      await tester.enterText(fields.at(1), '50');
      await tester.enterText(fields.at(2), '999');
      await tester.tap(find.text('Ajouter le programme'));
      await tester.pumpAndSettle();
      expect(find.text('100–200'), findsOneWidget);
      expect(find.text('1–180'), findsOneWidget);
    });
  });

  group('maintenance form', () {
    testWidgets('the preview names the kind and follows the technician',
        (tester) async {
      tall(tester);
      await pumpApp(
        tester,
        const Scaffold(body: MaintenanceRecordFormSheet(deviceId: 'd1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Maintenance préventive'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ex : SAV Melag, technicien interne...'),
        'SAV Melag',
      );
      await tester.pumpAndSettle();
      expect(find.text('SAV Melag'), findsWidgets);
    });
  });

  group('supplier form', () {
    testWidgets('the preview follows the typing and a bad e-mail is refused',
        (tester) async {
      tall(tester);
      await pumpApp(
        tester,
        const Scaffold(body: SupplierFormSheet()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nom du fournisseur'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Dental Plus',
      );
      await tester.pumpAndSettle();
      // In the field and in the preview.
      expect(find.text('Dental Plus'), findsWidgets);
      expect(find.text('DP'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).at(1),
        'pas-un-email',
      );
      await tester.tap(find.text('Enregistrer le fournisseur'));
      await tester.pumpAndSettle();
      expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
    });

    testWidgets('a missing name is refused', (tester) async {
      tall(tester);
      await pumpApp(tester, const Scaffold(body: SupplierFormSheet()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer le fournisseur'));
      await tester.pumpAndSettle();
      expect(find.text('Requis.'), findsOneWidget);
    });
  });

  group('product family shortcut', () {
    testWidgets('creating a family selects it in the form', (tester) async {
      tall(tester);
      final categories = _Categories();
      final stock = _Stock();
      final products = _Products();
      when(() => categories.list()).thenAnswer((_) async => const []);
      when(() => categories.create('Gants')).thenAnswer(
        (_) async => const ProductCategoryData(id: 'c-new', name: 'Gants'),
      );
      when(() => stock.listOptions(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => (
                batches: <StockOption>[],
                locations: <StockOption>[],
              ));
      _register<ProductCategoryRepository>(categories);
      _register<StockRepository>(stock);
      _register<ProductRepository>(products);

      await pumpApp(
        tester,
        BlocProvider(
          create: (_) => ProductListBloc(products),
          child: const Scaffold(body: ProductFormSheet()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nouvelle famille'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Gants');
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      verify(() => categories.create('Gants')).called(1);
      expect(find.text('Famille créée.'), findsOneWidget);
      // It is now the form's family: shown in the preview.
      expect(find.text('Gants'), findsWidgets);
    });

    testWidgets('an empty name creates nothing', (tester) async {
      tall(tester);
      final categories = _Categories();
      final stock = _Stock();
      when(() => categories.list()).thenAnswer((_) async => const []);
      when(() => stock.listOptions(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => (
                batches: <StockOption>[],
                locations: <StockOption>[],
              ));
      _register<ProductCategoryRepository>(categories);
      _register<StockRepository>(stock);
      _register<ProductRepository>(_Products());

      await pumpApp(tester, const Scaffold(body: ProductFormSheet()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nouvelle famille'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();
      verifyNever(() => categories.create(any()));
    });
  });
}
