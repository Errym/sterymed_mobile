// The Stock option and the dashboard modules on a small phone with large text,
// a normal phone and a tablet, with long French names. A RenderFlex overflow or
// build error fails the test, so a clipped price or hidden button cannot ship.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/core/router/routes.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/alerts/data/models/alert_data.dart';
import 'package:steriymed_mobile/features/alerts/data/repositories/alert_repository.dart';
import 'package:steriymed_mobile/features/alerts/presentation/screens/alert_list_screen.dart';
import 'package:steriymed_mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:steriymed_mobile/features/catalog/data/models/product_category_data.dart';
import 'package:steriymed_mobile/features/catalog/data/models/product_data.dart';
import 'package:steriymed_mobile/features/catalog/data/repositories/product_category_repository.dart';
import 'package:steriymed_mobile/features/catalog/data/repositories/product_repository.dart';
import 'package:steriymed_mobile/features/catalog/presentation/screens/product_list_screen.dart';
import 'package:steriymed_mobile/features/catalog/presentation/widgets/product_form_sheet.dart';
import 'package:steriymed_mobile/features/patients/data/models/patient_data.dart';
import 'package:steriymed_mobile/features/patients/presentation/widgets/patient_detail_sheet.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/laboratory_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_summary_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/repositories/prosthetic_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/screens/prosthetic_laboratories_screen.dart';
import 'package:steriymed_mobile/features/purchases/data/models/purchase_order_data.dart';
import 'package:steriymed_mobile/features/purchases/data/models/purchase_order_line_data.dart';
import 'package:steriymed_mobile/features/purchases/data/repositories/purchase_repository.dart';
import 'package:steriymed_mobile/features/purchases/presentation/screens/purchase_order_detail_screen.dart';
import 'package:steriymed_mobile/features/purchases/presentation/screens/purchase_order_list_screen.dart';
import 'package:steriymed_mobile/features/reporting/data/models/evidence_search_result_data.dart';
import 'package:steriymed_mobile/features/reporting/data/repositories/evidence_search_repository.dart';
import 'package:steriymed_mobile/features/sites/data/models/site_data.dart';
import 'package:steriymed_mobile/features/sites/data/repositories/site_repository.dart';
import 'package:steriymed_mobile/features/sites/presentation/screens/site_list_screen.dart';
import 'package:steriymed_mobile/features/stock/data/models/batch_data.dart';
import 'package:steriymed_mobile/features/stock/data/models/stock_level_data.dart';
import 'package:steriymed_mobile/features/stock/data/models/stock_option.dart';
import 'package:steriymed_mobile/features/stock/data/repositories/stock_repository.dart';
import 'package:steriymed_mobile/features/stock/presentation/screens/batch_list_screen.dart';
import 'package:steriymed_mobile/features/stock/presentation/screens/stock_level_list_screen.dart';
import 'package:steriymed_mobile/features/suppliers/data/models/supplier_data.dart';
import 'package:steriymed_mobile/features/suppliers/data/models/supplier_product_data.dart';
import 'package:steriymed_mobile/features/suppliers/data/repositories/supplier_repository.dart';
import 'package:steriymed_mobile/features/suppliers/presentation/screens/supplier_detail_screen.dart';
import 'package:steriymed_mobile/features/suppliers/presentation/screens/supplier_list_screen.dart';
import 'package:steriymed_mobile/features/suppliers/presentation/widgets/supplier_form_sheet.dart';

import '../helpers/pump_app.dart';

class _Session extends Mock implements SessionStore {}

class _Stock extends Mock implements StockRepository {}

class _Products extends Mock implements ProductRepository {}

class _Categories extends Mock implements ProductCategoryRepository {}

class _Suppliers extends Mock implements SupplierRepository {}

class _Purchases extends Mock implements PurchaseRepository {}

class _Sites extends Mock implements SiteRepository {}

class _Prosthetic extends Mock implements ProstheticRepository {}

class _Alerts extends Mock implements AlertRepository {}

class _Evidence extends Mock implements EvidenceSearchRepository {}

void _register<T extends Object>(T v) {
  if (GetIt.instance.isRegistered<T>()) GetIt.instance.unregister<T>();
  GetIt.instance.registerSingleton<T>(v);
}

const _viewports = <String, (Size, double)>{
  'small phone, text 130%': (Size(320, 568), 1.3),
  'phone, text 100%': (Size(390, 844), 1.0),
  'tablet': (Size(1024, 768), 1.0),
};

Future<void> _loadInter() async {
  final loader = FontLoader('Inter');
  for (final f in const ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Inter-$f.ttf'));
  }
  await loader.load();
}

String _day(int offset) {
  final d = DateTime.now().add(Duration(days: offset));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

StockLevelData _row(String id, String name, int qty, {int? exp}) =>
    StockLevelData.fromJson({
      'id': id,
      'product_id': 'p-$id',
      'product_name': name,
      'product_reference': 'REF-LONGUE-$id',
      'product_unit': 'boîtes',
      'location_id': 'l-$id',
      'location_name': 'Réserve centrale du sous-sol · Armoire sécurisée A',
      'batch_id': 'b-$id',
      'batch_number': 'LOT-2026-0512-$id',
      'quantity': qty,
      'min_threshold': 20,
      if (exp != null) 'expiry_date': _day(exp),
    });

const _longName = 'Gants nitrile non poudrés taille M, boîte de 100 unités '
    'stériles à usage unique';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Session session;
  late _Stock stock;
  late _Products products;
  late _Suppliers suppliers;
  late _Purchases purchases;

  setUpAll(_loadInter);

  setUp(() {
    session = _Session();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.userName).thenReturn('Docteur Prénom-Composé Nom');
    _register<SessionStore>(session);

    stock = _Stock();
    when(() => stock.listLevels(
          search: any(named: 'search'),
          forceRefresh: any(named: 'forceRefresh'),
          inStockOnly: any(named: 'inStockOnly'),
        )).thenAnswer((_) async => [
          _row('a', _longName, 45),
          _row('b', 'Compresses stériles 10x10 cm', 8),
          _row('c', 'Anesthésique articaïne 1/200000', 2, exp: -3),
        ]);
    when(() => stock.listBatches()).thenAnswer((_) async => [
          BatchData.fromJson({
            'id': 'b-a',
            'product_name': _longName,
            'supplier_name': 'Fournisseur Dentaire du Grand Est International',
            'batch_number': 'LOT-2026-0512-A',
            'expiry_date': _day(25),
            'received_at': '2026-09-01T09:00:00+00:00',
            'status': 'active',
            'qty_on_hand': 45,
          }),
          BatchData.fromJson(const {
            'id': 'b-q',
            'product_name': 'Compresses',
            'supplier_name': 'MedStock',
            'batch_number': 'LOT-Q',
            'status': 'quarantined',
            'qty_on_hand': 9,
          }),
        ]);
    when(() => stock.listOptions(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => (
              batches: <StockOption>[],
              locations: [const StockOption(id: 'l1', label: 'Réserve')],
            ));
    _register<StockRepository>(stock);

    products = _Products();
    when(() => products.list(
          search: any(named: 'search'),
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => const [
          ProductData(
            id: 'p-a',
            name: _longName,
            reference: 'REF-LONGUE-a',
            unit: 'boîte de 100',
            minThreshold: 20,
            isSterilizable: true,
            barcode: '3401234567890',
            categoryId: 'c1',
          ),
        ]);
    _register<ProductRepository>(products);
    final categories = _Categories();
    when(() => categories.list()).thenAnswer((_) async => const [
          ProductCategoryData(
              id: 'c1', name: 'Consommables de protection individuelle'),
        ]);
    _register<ProductCategoryRepository>(categories);

    suppliers = _Suppliers();
    const supplier = SupplierData(
      id: 'sup-1',
      name: 'Fournisseur Dentaire du Grand Est International',
      email: 'commandes.longue-adresse@fournisseur-dentaire.example.fr',
      phone: '+33 1 42 68 00 22',
      address: '12 rue de la Paix, Bâtiment B, 75008 Paris, France',
    );
    when(() => suppliers.list(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => const [supplier]);
    when(() => suppliers.show('sup-1')).thenAnswer((_) async => supplier);
    when(() => suppliers.listProducts('sup-1',
            forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => const [
              SupplierProductData(
                id: 'l1',
                supplierId: 'sup-1',
                productId: 'p-a',
                supplierReference: 'GN-100-LONGUE-REFERENCE',
                packSize: 10,
                price: 1234.56,
              ),
            ]);
    _register<SupplierRepository>(suppliers);

    purchases = _Purchases();
    final order = PurchaseOrderData(
      id: 'abcdef12-3456',
      supplierId: 'sup-1',
      supplierName: supplier.name,
      status: 'partially_received',
      lines: const [
        PurchaseOrderLineData(
          id: 'ol1',
          productId: 'p-a',
          productName: _longName,
          qtyOrdered: 120,
          qtyReceived: 40,
          unitPrice: 1234.56,
        ),
        PurchaseOrderLineData(
          id: 'ol2',
          productId: 'p-b',
          productName: 'Lames de bistouri n°15 stériles',
          qtyOrdered: 25,
          qtyReceived: 25,
          unitPrice: 3,
        ),
      ],
      createdAt: DateTime(2026, 9, 1),
      orderedAt: DateTime(2026, 9, 2),
      expectedAt: DateTime(2026, 9, 10),
    );
    when(() => purchases.list(
          forceRefresh: any(named: 'forceRefresh'),
          status: any(named: 'status'),
        )).thenAnswer((_) async => CursorPage(items: [order]));
    when(() => purchases.show(any())).thenAnswer((_) async => order);
    when(() => purchases.receipts(any())).thenAnswer((_) async => []);
    _register<PurchaseRepository>(purchases);

    final sites = _Sites();
    when(() => sites.list(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => [
              SiteData.fromJson(const {
                'id': 's1',
                'name': 'Cabinet Dentaire du Centre-Ville de Paris Huitième',
                'address_line1': '12 rue de la Paix',
                'postal_code': '75008',
                'city': 'Paris',
                'timezone': 'Europe/Paris',
                'is_primary': true,
                'rooms_count': 12,
                'storage_locations_count': 34,
                'devices_count': 6,
              }),
            ]);
    _register<SiteRepository>(sites);

    final pro = _Prosthetic();
    when(() => pro.list(patientReference: any(named: 'patientReference')))
        .thenAnswer((_) async => const CursorPage(items: []));
    when(() => pro.listLaboratories(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => const [
              LaboratoryData(
                id: 'lab-1',
                name: 'Laboratoire de Prothèses Dentaires du Centre-Ville de Paris Huitième',
                contactName: 'Docteur Prénom-Composé Nom-Très-Long',
                contactPhone: '+33 1 42 68 00 22',
                contactEmail: 'commandes.longue-adresse@laboratoire-dentaire.example.fr',
                address: '12 rue de la Paix, Bâtiment B, 75008 Paris, France',
                notes: 'Livraison le mardi et le vendredi avant 10 h.',
              ),
            ]);
    when(() => pro.summary(
          laboratoryId: any(named: 'laboratoryId'),
          scope: any(named: 'scope'),
        )).thenAnswer((_) async => const ProstheticSummaryData(total: 12, urgent: 3));
    when(() => pro.list(laboratoryId: any(named: 'laboratoryId')))
        .thenAnswer((_) async => const CursorPage(items: []));
    _register<ProstheticRepository>(pro);
    final evidence = _Evidence();
    when(() => evidence.search(patientReference: any(named: 'patientReference')))
        .thenAnswer((_) async => CursorPage(items: [
              EvidenceSearchResultData(
                labelId: 'l',
                labelStatus: 'used',
                cycleNumber: 12345,
                deviceName: 'Autoclave Melag Vacuklav 40B+ salle de stérilisation',
                siteName: 'S',
                operatorName: 'O',
                batchNumber: 'LOT-2026-0512-A',
                patientReference: 'PAT-000042',
                practitionerName: 'Docteur Prénom-Composé Nom-Très-Long',
                procedure: 'Pose d\'implant dentaire avec greffe osseuse',
                usedAt: DateTime(2026, 9, 28),
              ),
            ]));
    _register<EvidenceSearchRepository>(evidence);
  });

  tearDown(() => GetIt.instance.reset());

  Future<void> check(
    WidgetTester tester,
    (Size, double) vp,
    Widget screen, {
    Future<void> Function()? then,
  }) async {
    tester.view.physicalSize = vp.$1 * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = vp.$2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearAllTestValues();
    });
    // A router so navigation helpers have somewhere to go.
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, __) => screen),
        GoRoute(
          path: '/app/purchases/:id',
          builder: (_, __) => const Scaffold(body: Text('PO')),
        ),
        GoRoute(
          path: Routes.stockIssue,
          builder: (_, __) => const Scaffold(body: Text('ISSUE')),
        ),
      ],
    );
    // Keep the whole report of any framework error: it names the widget (and
    // its file) that overflowed, which the bare message does not.
    final reports = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      reports.add(details.toString());
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
    await pumpAppWidget(tester, MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    if (then != null) {
      await then();
      await tester.pumpAndSettle();
    }
    final problem = tester.takeException();
    expect(
      problem,
      isNull,
      reason: reports.isEmpty ? '$problem' : reports.join(' ---- '),
    );
  }

  for (final vp in _viewports.entries) {
    group('on ${vp.key}', () {
      testWidgets('stock list, its detail sheet and the movement menu',
          (tester) async {
        await check(tester, vp.value, const StockLevelListScreen(),
            then: () async {
          await tester.tap(find.textContaining('articaïne'));
          await tester.pumpAndSettle();
          await tester.tapAt(const Offset(4, 4));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('stock-new-movement')));
          await tester.pumpAndSettle();
        });
      });

      testWidgets('lots and a lot\'s sheet', (tester) async {
        await check(tester, vp.value, const BatchListScreen(), then: () async {
          await tester.tap(find.textContaining('LOT-2026-0512-A').first);
          await tester.pumpAndSettle();
        });
      });

      testWidgets('catalogue, a product\'s sheet and the product form',
          (tester) async {
        await check(tester, vp.value, const ProductListScreen(),
            then: () async {
          await tester.tap(find.textContaining('Gants nitrile'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Modifier'));
          await tester.pumpAndSettle();
        });
      });

      testWidgets('product form on its own', (tester) async {
        await check(
          tester,
          vp.value,
          const Scaffold(body: ProductFormSheet()),
        );
      });

      testWidgets('suppliers list and detail', (tester) async {
        await check(tester, vp.value, const SupplierListScreen());
        await check(
          tester,
          vp.value,
          const SupplierDetailScreen(supplierId: 'sup-1'),
        );
      });

      testWidgets('supplier form', (tester) async {
        await check(
          tester,
          vp.value,
          const Scaffold(body: SupplierFormSheet()),
        );
      });

      testWidgets('orders list and detail', (tester) async {
        await check(tester, vp.value, const PurchaseOrderListScreen());
        await check(
          tester,
          vp.value,
          const PurchaseOrderDetailScreen(poId: 'abcdef12-3456'),
        );
      });

      testWidgets('sites', (tester) async {
        await check(tester, vp.value, const SiteListScreen());
      });

      testWidgets('alerts', (tester) async {
        final repo = _Alerts();
        AlertData al(String id, String type, AlertSeverity sev, String subject) =>
            AlertData(
              id: id,
              type: type,
              severity: sev,
              state: 'open',
              subjectType: subject,
              subjectId: 's$id',
              message: 'Cycle #12 failed a vacuum control test on the '
                  'autoclave of the main sterilization room, immediately.',
              createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
            );
        when(() => repo.getActiveAlerts(
              forceRefresh: any(named: 'forceRefresh'),
              type: any(named: 'type'),
              state: any(named: 'state'),
            )).thenAnswer((_) async => CursorPage(items: [
              al('1', 'failed_cycle', AlertSeverity.critical, r'App\Cycle'),
              al('2', 'low_stock', AlertSeverity.warning, 'Product'),
              al('3', 'near_expiry', AlertSeverity.info, 'Batch'),
            ]));
        await check(
          tester,
          vp.value,
          RepositoryProvider<AlertRepository>.value(
            value: repo,
            child: const AlertListScreen(),
          ),
        );
      });

      testWidgets('settings / profile', (tester) async {
        when(() => session.role).thenReturn('owner');
        when(() => session.userEmail)
            .thenReturn('docteur.nom-tres-long@cabinet-dentaire.example.fr');
        when(() => session.tenantName)
            .thenReturn('Cabinet Dentaire du Centre-Ville');
        when(() => session.isOwner).thenReturn(true);
        await check(tester, vp.value, const SettingsScreen());
      });

      testWidgets('laboratories, a laboratory sheet and the form', (tester) async {
        await check(tester, vp.value, const ProstheticLaboratoriesScreen(),
            then: () async {
          await tester.tap(find.byKey(const Key('lab-lab-1')));
          await tester.pumpAndSettle();
        });
      });

      testWidgets('patient sheet', (tester) async {
        await check(
          tester,
          vp.value,
          const Scaffold(
            body: PatientDetailSheet(
              patient: PatientData(id: 'p1', reference: 'PAT-000042'),
              canManage: true,
            ),
          ),
        );
      });
    });
  }
}
