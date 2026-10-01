// Editing a populated product: it must open without a dropdown assertion when
// the saved category/location is not among the loaded options, clearing a field
// must really clear it, and an invalid threshold must be refused (not turned
// into 0).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/features/catalog/data/models/product_category_data.dart';
import 'package:steriymed_mobile/features/catalog/data/models/product_data.dart';
import 'package:steriymed_mobile/features/catalog/data/repositories/product_category_repository.dart';
import 'package:steriymed_mobile/features/catalog/data/repositories/product_repository.dart';
import 'package:steriymed_mobile/features/catalog/presentation/bloc/product_list_bloc.dart';
import 'package:steriymed_mobile/features/catalog/presentation/widgets/product_form_sheet.dart';
import 'package:steriymed_mobile/features/stock/data/models/stock_option.dart';
import 'package:steriymed_mobile/features/stock/data/repositories/stock_repository.dart';
import 'package:steriymed_mobile/shared/widgets/inputs/app_dropdown.dart';

import '../helpers/pump_app.dart';

class _MockProducts extends Mock implements ProductRepository {}

class _MockCategories extends Mock implements ProductCategoryRepository {}

class _MockStock extends Mock implements StockRepository {}

class _FakeRequest extends Fake implements ProductCreateRequest {}

const _existing = ProductData(
  id: 'p1',
  name: 'Gants nitrile',
  reference: 'GANT-1',
  unit: 'box',
  minThreshold: 4,
  isSterilizable: false,
  barcode: '123456',
  categoryId: 'archived-category',
  defaultLocationId: 'archived-location',
);

void main() {
  late _MockProducts products;
  late _MockCategories categories;
  late _MockStock stock;

  setUpAll(() => registerFallbackValue(_FakeRequest()));

  setUp(() {
    products = _MockProducts();
    categories = _MockCategories();
    stock = _MockStock();
    when(
      () => products.list(
        search: any(named: 'search'),
        forceRefresh: any(named: 'forceRefresh'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => products.update(any(), any()),
    ).thenAnswer((_) async => _existing);
    when(() => categories.list()).thenAnswer(
      (_) async => [const ProductCategoryData(id: 'c1', name: 'Consommables')],
    );
    when(
      () => stock.listOptions(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer(
      (_) async => (
        batches: <StockOption>[],
        locations: [const StockOption(id: 'l1', label: 'Réserve')],
      ),
    );

    final di = GetIt.instance;
    for (final reset in [
      () => di.isRegistered<ProductRepository>()
          ? di.unregister<ProductRepository>()
          : null,
      () => di.isRegistered<ProductCategoryRepository>()
          ? di.unregister<ProductCategoryRepository>()
          : null,
      () => di.isRegistered<StockRepository>()
          ? di.unregister<StockRepository>()
          : null,
    ]) {
      reset();
    }
    di
      ..registerSingleton<ProductRepository>(products)
      ..registerSingleton<ProductCategoryRepository>(categories)
      ..registerSingleton<StockRepository>(stock);
  });

  tearDown(() {
    final di = GetIt.instance;
    di.unregister<ProductRepository>();
    di.unregister<ProductCategoryRepository>();
    di.unregister<StockRepository>();
  });

  Future<void> open(WidgetTester tester, {ProductData? existing}) async {
    // The sheet is a long, lazily built list: use a tall window so every field
    // is on screen.
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => ProductListBloc(products),
        child: Scaffold(body: ProductFormSheet(existing: existing)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a product whose category and location are not among the options opens '
    'without crashing and keeps them visible',
    (tester) async {
      await open(tester, existing: _existing);

      expect(tester.takeException(), isNull);
      expect(find.text(AppDropdown.unavailableLabel), findsNWidgets(2));
      expect(find.text('Gants nitrile'), findsOneWidget);
    },
  );

  testWidgets('saving without touching the dropdowns keeps the saved choices', (
    tester,
  ) async {
    await open(tester, existing: _existing);

    await tester.tap(find.text('Enregistrer le produit'));
    await tester.pumpAndSettle();

    final sent =
        verify(() => products.update('p1', captureAny())).captured.single
            as ProductCreateRequest;
    expect(sent.categoryId, 'archived-category');
    expect(sent.defaultLocationId, 'archived-location');
    expect(sent.barcode, '123456');
  });

  testWidgets('emptying the barcode sends a real clear, not an omission', (
    tester,
  ) async {
    await open(tester, existing: _existing);

    await tester.enterText(find.widgetWithText(TextFormField, '123456'), '');
    await tester.tap(find.text('Enregistrer le produit'));
    await tester.pumpAndSettle();

    final sent =
        verify(() => products.update('p1', captureAny())).captured.single
            as ProductCreateRequest;
    expect(sent.barcode, isNull);
    expect(sent.toUpdateJson().containsKey('barcode'), isTrue);
    expect(sent.toUpdateJson()['barcode'], isNull);
  });

  testWidgets('an invalid threshold is refused instead of becoming zero', (
    tester,
  ) async {
    await open(tester, existing: _existing);

    await tester.enterText(find.widgetWithText(TextFormField, '4'), 'abc');
    await tester.tap(find.text('Enregistrer le produit'));
    await tester.pumpAndSettle();

    expect(find.text('Entrez un nombre entier positif.'), findsOneWidget);
    verifyNever(() => products.update(any(), any()));
  });

  testWidgets('an empty threshold is refused', (tester) async {
    await open(tester, existing: _existing);

    await tester.enterText(find.widgetWithText(TextFormField, '4'), '');
    await tester.tap(find.text('Enregistrer le produit'));
    await tester.pumpAndSettle();

    expect(find.text('Requis.'), findsOneWidget);
    verifyNever(() => products.update(any(), any()));
  });

  testWidgets(
    'when the lists cannot be loaded the user is told, and nothing is '
    'silently emptied',
    (tester) async {
      when(() => categories.list()).thenThrow(Exception('réseau'));

      await open(tester, existing: _existing);

      expect(
        find.textContaining('n\'ont pas pu être chargées'),
        findsOneWidget,
      );
      expect(find.text(AppDropdown.unavailableLabel), findsNWidgets(2));
    },
  );
}
