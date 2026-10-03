// Regression tests for flows that open one sheet from another (or a form from
// a detail page). Each used to depend on a bloc or a context that was not
// there at that point, and failed only when a person actually tapped through.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/catalog/data/models/product_category_data.dart';
import 'package:steriymed_mobile/features/catalog/data/models/product_data.dart';
import 'package:steriymed_mobile/features/catalog/data/repositories/product_category_repository.dart';
import 'package:steriymed_mobile/features/catalog/data/repositories/product_repository.dart';
import 'package:steriymed_mobile/features/catalog/presentation/screens/product_list_screen.dart';
import 'package:steriymed_mobile/features/purchases/data/repositories/purchase_repository.dart';
import 'package:steriymed_mobile/features/stock/data/models/stock_level_data.dart';
import 'package:steriymed_mobile/features/stock/data/models/stock_option.dart';
import 'package:steriymed_mobile/features/stock/data/repositories/stock_repository.dart';
import 'package:steriymed_mobile/features/suppliers/data/models/supplier_data.dart';
import 'package:steriymed_mobile/features/suppliers/data/repositories/supplier_repository.dart';
import 'package:steriymed_mobile/features/suppliers/presentation/screens/supplier_detail_screen.dart';

import '../helpers/pump_app.dart';

class _Suppliers extends Mock implements SupplierRepository {}

class _Purchases extends Mock implements PurchaseRepository {}

class _Products extends Mock implements ProductRepository {}

class _Categories extends Mock implements ProductCategoryRepository {}

class _Stock extends Mock implements StockRepository {}

class _Session extends Mock implements SessionStore {}

void _register<T extends Object>(T v) {
  if (GetIt.I.isRegistered<T>()) GetIt.I.unregister<T>();
  GetIt.I.registerSingleton<T>(v);
}

void main() {
  late _Session session;

  setUp(() {
    session = _Session();
    when(() => session.hasPermission(any())).thenReturn(true);
    _register<SessionStore>(session);
  });

  tearDown(() {
    for (final unregister in <void Function()>[
      () => GetIt.I.isRegistered<SessionStore>()
          ? GetIt.I.unregister<SessionStore>()
          : null,
      () => GetIt.I.isRegistered<SupplierRepository>()
          ? GetIt.I.unregister<SupplierRepository>()
          : null,
      () => GetIt.I.isRegistered<PurchaseRepository>()
          ? GetIt.I.unregister<PurchaseRepository>()
          : null,
      () => GetIt.I.isRegistered<ProductRepository>()
          ? GetIt.I.unregister<ProductRepository>()
          : null,
      () => GetIt.I.isRegistered<ProductCategoryRepository>()
          ? GetIt.I.unregister<ProductCategoryRepository>()
          : null,
      () => GetIt.I.isRegistered<StockRepository>()
          ? GetIt.I.unregister<StockRepository>()
          : null,
    ]) {
      unregister();
    }
  });

  testWidgets('editing a supplier from its detail page opens the form',
      (tester) async {
    final suppliers = _Suppliers();
    final purchases = _Purchases();
    final products = _Products();
    const supplier = SupplierData(id: 'sup-1', name: 'Dental Plus');
    when(() => suppliers.show('sup-1')).thenAnswer((_) async => supplier);
    when(() => suppliers.listProducts('sup-1',
            forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => const []);
    when(() => products.list(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => const []);
    when(() => purchases.list(
          forceRefresh: any(named: 'forceRefresh'),
          status: any(named: 'status'),
        )).thenAnswer((_) async => const CursorPage(items: []));
    _register<SupplierRepository>(suppliers);
    _register<PurchaseRepository>(purchases);
    _register<ProductRepository>(products);

    await pumpApp(tester, const SupplierDetailScreen(supplierId: 'sup-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Modifier'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Modifier le fournisseur'), findsOneWidget);
  });

  testWidgets('"Modifier" in a product\'s sheet opens the product form',
      (tester) async {
    final products = _Products();
    final categories = _Categories();
    final stock = _Stock();
    const product = ProductData(
      id: 'p1',
      name: 'Gants nitrile',
      reference: 'GN-1',
      unit: 'boîte',
      minThreshold: 5,
      isSterilizable: false,
    );
    when(() => products.list(
          search: any(named: 'search'),
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => const [product]);
    when(() => categories.list()).thenAnswer(
      (_) async => const [ProductCategoryData(id: 'c1', name: 'Gants')],
    );
    when(() => stock.listLevels(
          search: any(named: 'search'),
          forceRefresh: any(named: 'forceRefresh'),
          inStockOnly: any(named: 'inStockOnly'),
        )).thenAnswer((_) async => const <StockLevelData>[]);
    when(() => stock.listOptions(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer(
      (_) async => (
        batches: <StockOption>[],
        locations: [const StockOption(id: 'l1', label: 'Réserve')],
      ),
    );
    _register<ProductRepository>(products);
    _register<ProductCategoryRepository>(categories);
    _register<StockRepository>(stock);

    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, const ProductListScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gants nitrile'));
    await tester.pumpAndSettle();
    expect(find.text('Fiche produit'.toUpperCase()), findsOneWidget);

    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Modifier produit'), findsOneWidget);
  });
}
