// The dashboard modules as a clinic uses them: suppliers, patients, sites and
// the non-conformity form. Each screen shows real fields, only what the role
// may see, and never an invented figure.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/features/catalog/data/models/product_data.dart';
import 'package:steriymed_mobile/features/catalog/data/repositories/product_repository.dart';
import 'package:steriymed_mobile/features/patients/data/models/patient_data.dart';
import 'package:steriymed_mobile/features/patients/presentation/widgets/patient_detail_sheet.dart';
import 'package:steriymed_mobile/features/prosthetic/data/repositories/prosthetic_repository.dart';
import 'package:steriymed_mobile/features/purchases/data/models/purchase_order_data.dart';
import 'package:steriymed_mobile/features/purchases/data/repositories/purchase_repository.dart';
import 'package:steriymed_mobile/features/reporting/data/models/evidence_search_result_data.dart';
import 'package:steriymed_mobile/features/reporting/data/repositories/evidence_search_repository.dart';
import 'package:steriymed_mobile/features/sites/data/models/site_data.dart';
import 'package:steriymed_mobile/features/sites/data/repositories/site_repository.dart';
import 'package:steriymed_mobile/features/sites/presentation/screens/site_list_screen.dart';
import 'package:steriymed_mobile/features/suppliers/data/models/supplier_data.dart';
import 'package:steriymed_mobile/features/suppliers/data/models/supplier_product_data.dart';
import 'package:steriymed_mobile/features/suppliers/data/repositories/supplier_repository.dart';
import 'package:steriymed_mobile/features/suppliers/presentation/screens/supplier_detail_screen.dart';
import 'package:steriymed_mobile/features/suppliers/presentation/screens/supplier_list_screen.dart';
import 'package:steriymed_mobile/shared/widgets/layout/detail_kit.dart';

import '../helpers/pump_app.dart';

class _SupplierRepo extends Mock implements SupplierRepository {}

class _PurchaseRepo extends Mock implements PurchaseRepository {}

class _ProductRepo extends Mock implements ProductRepository {}

class _SiteRepo extends Mock implements SiteRepository {}

class _ProstheticRepo extends Mock implements ProstheticRepository {}

class _EvidenceRepo extends Mock implements EvidenceSearchRepository {}

class _Session extends Mock implements SessionStore {}

PurchaseOrderData _order(String id, String supplier, String status,
        {DateTime? orderedAt}) =>
    PurchaseOrderData(
      id: id,
      supplierId: supplier,
      supplierName: 'X',
      status: status,
      lines: const [],
      createdAt: DateTime(2026, 9, 1),
      orderedAt: orderedAt,
    );

void main() {
  late _SupplierRepo suppliers;
  late _PurchaseRepo purchases;
  late _ProductRepo products;
  late _SiteRepo sites;
  late _Session session;

  void register<T extends Object>(T v) {
    if (GetIt.I.isRegistered<T>()) GetIt.I.unregister<T>();
    GetIt.I.registerSingleton<T>(v);
  }

  void allow(Set<String> permissions) => when(() => session.hasPermission(any()))
      .thenAnswer((i) => permissions.contains(i.positionalArguments.first));

  setUp(() {
    suppliers = _SupplierRepo();
    purchases = _PurchaseRepo();
    products = _ProductRepo();
    sites = _SiteRepo();
    session = _Session();
    allow({});
    register<SupplierRepository>(suppliers);
    register<PurchaseRepository>(purchases);
    register<ProductRepository>(products);
    register<SiteRepository>(sites);
    register<SessionStore>(session);
  });

  tearDown(() {
    for (final t in [
      SupplierRepository,
      PurchaseRepository,
      ProductRepository,
      SiteRepository,
      SessionStore,
      ProstheticRepository,
      EvidenceSearchRepository,
    ]) {
      if (t == SupplierRepository) GetIt.I.unregister<SupplierRepository>();
      if (t == PurchaseRepository) GetIt.I.unregister<PurchaseRepository>();
      if (t == ProductRepository) GetIt.I.unregister<ProductRepository>();
      if (t == SiteRepository) GetIt.I.unregister<SiteRepository>();
      if (t == SessionStore) GetIt.I.unregister<SessionStore>();
      if (t == ProstheticRepository &&
          GetIt.I.isRegistered<ProstheticRepository>()) {
        GetIt.I.unregister<ProstheticRepository>();
      }
      if (t == EvidenceSearchRepository &&
          GetIt.I.isRegistered<EvidenceSearchRepository>()) {
        GetIt.I.unregister<EvidenceSearchRepository>();
      }
    }
  });

  const dental = SupplierData(
    id: 'sup-1',
    name: 'Dental Plus',
    email: 'contact@dentalplus.fr',
    phone: '01 42 68 00 22',
    address: '12 rue de la Paix, 75008 Paris',
  );

  group('suppliers', () {
    testWidgets('the list shows contact tags and real order figures',
        (tester) async {
      allow({'suppliers.view', 'suppliers.manage'});
      when(() => suppliers.list(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => [
                dental,
                const SupplierData(id: 'sup-2', name: 'MedStock'),
              ]);
      when(() => purchases.list(
            forceRefresh: any(named: 'forceRefresh'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => CursorPage(items: [
            _order('o1', 'sup-1', 'ordered', orderedAt: DateTime(2026, 9, 20)),
            _order('o2', 'sup-1', 'received', orderedAt: DateTime(2026, 8, 1)),
          ]));
      await pumpApp(tester, const SupplierListScreen());
      await tester.pumpAndSettle();

      expect(find.text('2 FOURNISSEURS'), findsOneWidget);
      expect(find.text('Dental Plus'), findsOneWidget);
      expect(find.text('01 42 68 00 22'), findsOneWidget);
      expect(find.text('contact@dentalplus.fr'), findsOneWidget);
      expect(find.text('1 commande en cours'), findsWidgets);
      // A supplier with no order says so, only because the order list was
      // complete.
      expect(find.text('Aucune commande'), findsOneWidget);
    });

    testWidgets('when the order list is incomplete no figure is invented',
        (tester) async {
      allow({'suppliers.view'});
      when(() => suppliers.list(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => [dental]);
      when(() => purchases.list(
            forceRefresh: any(named: 'forceRefresh'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => CursorPage(
            items: [_order('o1', 'sup-1', 'ordered')],
            nextCursor: 'more',
          ));
      await pumpApp(tester, const SupplierListScreen());
      await tester.pumpAndSettle();
      expect(find.textContaining('commande'), findsNothing);
      expect(find.text('Aucune commande'), findsNothing);
    });

    testWidgets('search narrows the list and an empty result is explained',
        (tester) async {
      allow({'suppliers.view'});
      when(() => suppliers.list(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => [
                dental,
                const SupplierData(id: 'sup-2', name: 'MedStock'),
              ]);
      when(() => purchases.list(
            forceRefresh: any(named: 'forceRefresh'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => const CursorPage(items: []));
      await pumpApp(tester, const SupplierListScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'medstock');
      await tester.pumpAndSettle();
      expect(find.text('MedStock'), findsOneWidget);
      expect(find.text('Dental Plus'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Aucun résultat'), findsOneWidget);
    });

    testWidgets('a role that may not manage suppliers gets no add button or '
        'menu', (tester) async {
      allow({'suppliers.view'});
      when(() => suppliers.list(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => [dental]);
      when(() => purchases.list(
            forceRefresh: any(named: 'forceRefresh'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => const CursorPage(items: []));
      await pumpApp(tester, const SupplierListScreen());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Nouveau fournisseur'), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('the detail offers call, e-mail and map for what exists, and '
        'the linked products with their prices', (tester) async {
      allow({'suppliers.view', 'suppliers.manage'});
      when(() => suppliers.show('sup-1')).thenAnswer((_) async => dental);
      when(() => suppliers.listProducts('sup-1',
              forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => const [
                SupplierProductData(
                  id: 'l1',
                  supplierId: 'sup-1',
                  productId: 'p1',
                  supplierReference: 'GN-100',
                  packSize: 10,
                  price: 12.5,
                ),
              ]);
      when(() => products.list(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => const [
                ProductData(
                  id: 'p1',
                  name: 'Gants nitrile',
                  reference: 'REF-1',
                  unit: 'boîte',
                  minThreshold: 5,
                  isSterilizable: false,
                ),
              ]);
      when(() => purchases.list(
            forceRefresh: any(named: 'forceRefresh'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => CursorPage(items: [
            _order('o1', 'sup-1', 'ordered', orderedAt: DateTime(2026, 9, 20)),
          ]));
      tester.view.physicalSize = const Size(1000, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(tester, const SupplierDetailScreen(supplierId: 'sup-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('contact-call')), findsOneWidget);
      expect(find.byKey(const Key('contact-email')), findsOneWidget);
      expect(find.byKey(const Key('contact-map')), findsOneWidget);
      expect(find.text('Gants nitrile'), findsOneWidget);
      expect(find.text('RÉF. FOURNISSEUR GN-100'), findsOneWidget);
      expect(find.text('Conditionnement ×10'), findsOneWidget);
      expect(find.text('Commandes en cours'), findsOneWidget);
      expect(find.text('Lier un produit'), findsOneWidget);
    });

    testWidgets('a supplier with only a name has no contact buttons',
        (tester) async {
      allow({'suppliers.view'});
      when(() => suppliers.show('sup-2')).thenAnswer(
          (_) async => const SupplierData(id: 'sup-2', name: 'MedStock'));
      when(() => suppliers.listProducts('sup-2',
              forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => const []);
      when(() => products.list(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => const []);
      when(() => purchases.list(
            forceRefresh: any(named: 'forceRefresh'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => const CursorPage(items: []));
      await pumpApp(tester, const SupplierDetailScreen(supplierId: 'sup-2'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('contact-call')), findsNothing);
      expect(find.byKey(const Key('contact-email')), findsNothing);
      expect(find.byKey(const Key('contact-map')), findsNothing);
      expect(find.text('Lier un produit'), findsNothing);
    });
  });

  group('sites', () {
    testWidgets('shows the counts the server sent and a way to find the site',
        (tester) async {
      when(() => sites.list(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => [
                SiteData.fromJson(const {
                  'id': 's1',
                  'name': 'Cabinet Paris 8e',
                  'address_line1': '12 rue de la Paix',
                  'postal_code': '75008',
                  'city': 'Paris',
                  'timezone': 'Europe/Paris',
                  'is_primary': true,
                  'rooms_count': 4,
                  'storage_locations_count': 1,
                  'devices_count': 2,
                }),
                SiteData.fromJson(const {'id': 's2', 'name': 'Annexe'}),
              ]);
      await pumpApp(tester, const SiteListScreen());
      await tester.pumpAndSettle();

      expect(find.text('SITE PRINCIPAL'), findsOneWidget);
      expect(find.text('12 rue de la Paix, 75008 Paris'), findsOneWidget);
      expect(find.text('4 salles'), findsOneWidget);
      expect(find.text('1 emplacement'), findsOneWidget);
      expect(find.text('2 appareils'), findsOneWidget);
      // Only the site with an address offers the map.
      expect(find.byKey(const Key('contact-map')), findsOneWidget);
      // The site without counts shows none, rather than zeros.
      expect(find.text('0 salle'), findsNothing);
    });
  });

  group('patients', () {
    testWidgets('the file lists prosthetic work and sterile material for a '
        'role that may read both', (tester) async {
      allow({'prosthetic_cases.view', 'usages.view'});
      final pro = _ProstheticRepo();
      final evidence = _EvidenceRepo();
      register<ProstheticRepository>(pro);
      register<EvidenceSearchRepository>(evidence);
      when(() => pro.list(patientReference: 'PAT-000042'))
          .thenAnswer((_) async => const CursorPage(items: []));
      when(() => evidence.search(patientReference: 'PAT-000042'))
          .thenAnswer((_) async => CursorPage(items: [
                EvidenceSearchResultData(
                  labelId: 'l1',
                  labelStatus: 'used',
                  cycleNumber: 7,
                  deviceName: 'Autoclave A1',
                  siteName: 'Cabinet',
                  operatorName: 'Claire',
                  batchNumber: 'LOT-9',
                  patientReference: 'PAT-000042',
                  practitionerName: 'Dr Martin',
                  procedure: 'Détartrage',
                  usedAt: DateTime(2026, 9, 28),
                ),
              ]));
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        const Scaffold(
          body: PatientDetailSheet(
            patient: PatientData(id: 'p1', reference: 'PAT-000042'),
            canManage: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DOSSIER PATIENT'), findsOneWidget);
      expect(find.text('PAT-000042'), findsOneWidget);
      expect(find.text('PA'), findsOneWidget);
      expect(find.text('Aucun dossier prothétique pour ce patient.'),
          findsOneWidget);
      expect(find.text('Détartrage'), findsOneWidget);
      expect(find.text('Cycle #7'), findsOneWidget);
      expect(find.text('Lot LOT-9'), findsOneWidget);
      // Cannot delete without the right.
      expect(find.text('Supprimer ce dossier'), findsNothing);
    });

    testWidgets('another patient whose reference merely contains this one is '
        'never shown', (tester) async {
      allow({'usages.view'});
      final evidence = _EvidenceRepo();
      register<EvidenceSearchRepository>(evidence);
      EvidenceSearchResultData use(String ref, String procedure) =>
          EvidenceSearchResultData(
            labelId: ref,
            labelStatus: 'used',
            cycleNumber: 1,
            deviceName: 'A1',
            siteName: 'S',
            operatorName: 'O',
            patientReference: ref,
            practitionerName: 'Dr',
            procedure: procedure,
            usedAt: DateTime(2026, 9, 1),
          );
      // The server filter is a substring match: it returns both.
      when(() => evidence.search(patientReference: 'PAT-00001'))
          .thenAnswer((_) async => CursorPage(items: [
                use('PAT-00001', 'Soin du bon patient'),
                use('PAT-000010', "Soin d'un autre patient"),
                use('pat-00001', 'Même patient, casse différente'),
              ]));
      await pumpApp(
        tester,
        const Scaffold(
          body: PatientDetailSheet(
            patient: PatientData(id: 'p1', reference: 'PAT-00001'),
            canManage: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Soin du bon patient'), findsOneWidget);
      expect(find.text('Même patient, casse différente'), findsOneWidget);
      expect(find.text("Soin d'un autre patient"), findsNothing);
    });

    testWidgets('a role with neither right sees the reference only',
        (tester) async {
      allow({});
      await pumpApp(
        tester,
        const Scaffold(
          body: PatientDetailSheet(
            patient: PatientData(id: 'p1', reference: 'PAT-000042'),
            canManage: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PAT-000042'), findsOneWidget);
      expect(find.text('DOSSIERS PROTHÉTIQUES'), findsNothing);
      expect(find.text('MATÉRIEL STÉRILE UTILISÉ'), findsNothing);
    });

    test('initials are letters, not the first digit of the number', () {
      expect(const PatientData(id: 'a', reference: 'PAT-000042').initials, 'PA');
      expect(const PatientData(id: 'a', reference: '000042').initials, '0');
      expect(const PatientData(id: 'a', reference: '').initials, '?');
    });
  });

  group('detail kit', () {
    testWidgets('contact actions only exist for values that exist',
        (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: ContactActions(phone: '0102030405', email: '  '),
        ),
      );
      expect(find.byKey(const Key('contact-call')), findsOneWidget);
      expect(find.byKey(const Key('contact-email')), findsNothing);
      expect(find.byKey(const Key('contact-map')), findsNothing);
    });
  });
}
