// The logic behind the dashboard modules (suppliers, sites, devices, audit,
// roles, contact actions): computed from real fields, never invented.

import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/utils/contact_launcher.dart';
import 'package:steriymed_mobile/core/utils/role_labels.dart';
import 'package:steriymed_mobile/features/devices/data/models/device_detail.dart';
import 'package:steriymed_mobile/features/history/data/models/audit_event_data.dart';
import 'package:steriymed_mobile/features/purchases/data/models/purchase_order_data.dart';
import 'package:steriymed_mobile/features/sites/data/models/site_data.dart';
import 'package:steriymed_mobile/features/suppliers/data/models/supplier_order_stats.dart';
import 'package:steriymed_mobile/shared/widgets/layout/detail_kit.dart';

PurchaseOrderData _order(
  String id,
  String supplier,
  String status, {
  DateTime? orderedAt,
  DateTime? createdAt,
}) =>
    PurchaseOrderData(
      id: id,
      supplierId: supplier,
      supplierName: supplier,
      status: status,
      lines: const [],
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      orderedAt: orderedAt,
    );

void main() {
  group('supplier order stats', () {
    test('counts per supplier, open orders and the last order date', () {
      final stats = SupplierOrderStats.bySupplier([
        _order('1', 'A', 'ordered', orderedAt: DateTime(2026, 3, 1)),
        _order('2', 'A', 'partially_received', orderedAt: DateTime(2026, 5, 1)),
        _order('3', 'A', 'received', orderedAt: DateTime(2026, 2, 1)),
        _order('4', 'B', 'cancelled', createdAt: DateTime(2026, 4, 4)),
      ]);
      expect(stats['A']!.total, 3);
      expect(stats['A']!.open, 2);
      expect(stats['A']!.lastOrderedAt, DateTime(2026, 5, 1));
      expect(stats['B']!.open, 0);
      // A cancelled order falls back to its creation date.
      expect(stats['B']!.lastOrderedAt, DateTime(2026, 4, 4));
      expect(stats.containsKey('C'), isFalse,
          reason: 'no entry for a supplier with no order');
    });

    test('a draft is not "to come"', () {
      expect(SupplierOrderStats.isOpen(_order('1', 'A', 'draft')), isFalse);
      expect(SupplierOrderStats.isOpen(_order('1', 'A', 'ordered')), isTrue);
    });
  });

  group('site data', () {
    test('keeps the counts the server sends and builds a map-ready address',
        () {
      final s = SiteData.fromJson(const {
        'id': 's1',
        'name': 'Cabinet Paris 8e',
        'address_line1': '12 rue de la Paix',
        'address_line2': 'Bâtiment B',
        'postal_code': '75008',
        'city': 'Paris',
        'country_code': 'FR',
        'timezone': 'Europe/Paris',
        'is_primary': true,
        'rooms_count': 4,
        'storage_locations_count': 9,
        'devices_count': 2,
      });
      expect(s.roomsCount, 4);
      expect(s.storageLocationsCount, 9);
      expect(s.devicesCount, 2);
      expect(s.timezone, 'Europe/Paris');
      expect(s.fullAddress, '12 rue de la Paix, Bâtiment B, 75008 Paris');
      expect(s.archived, isFalse);
    });

    test('a count the server did not send is unknown, not zero', () {
      final s = SiteData.fromJson(const {'id': 's', 'name': 'X'});
      expect(s.roomsCount, isNull);
      expect(s.devicesCount, isNull);
      expect(s.fullAddress, isNull);
    });

    test('an archived site is flagged', () {
      final s = SiteData.fromJson(
        const {'id': 's', 'name': 'X', 'archived_at': '2026-01-01'},
      );
      expect(s.archived, isTrue);
    });
  });

  group('devices', () {
    test('the kind, status and dates come through in French', () {
      final d = DeviceDetail.fromJson(const {
        'id': 'd',
        'name': 'Autoclave A1',
        'kind': 'autoclave',
        'status': 'maintenance',
        'manufacturer': 'Melag',
        'model': 'Vacuklav 40B+',
        'commissioned_at': '2025-03-10',
        'site_id': 'site-1',
      });
      expect(d.kindLabel, 'Autoclave');
      expect(d.statusLabel, 'En maintenance');
      expect(d.isActive, isFalse);
      expect(d.makeAndModel, 'Melag Vacuklav 40B+');
      expect(d.commissionedAt, DateTime(2025, 3, 10));
    });

    test('the site name is filled in from the site id, nothing invented', () {
      const d = DeviceDetail(id: 'd', name: 'A', siteId: 'site-1');
      expect(d.siteName, isNull);
      expect(d.withSiteName('Cabinet').siteName, 'Cabinet');
      // Unknown site: keeps what it had (nothing).
      expect(d.withSiteName(null).siteName, isNull);
    });

    test('make and model with only one of them', () {
      const d = DeviceDetail(id: 'd', name: 'A', model: 'X1');
      expect(d.makeAndModel, 'X1');
      expect(const DeviceDetail(id: 'd', name: 'A').makeAndModel, isNull);
    });
  });

  group('audit changes', () {
    AuditEventData event(Map<String, dynamic>? before, Map<String, dynamic>? after) =>
        AuditEventData.fromJson({
          'id': 'e',
          'action': 'site.updated',
          'occurred_at': '2026-10-02T10:00:00Z',
          'old_values': before,
          'new_values': after,
        });

    test('lists only the fields whose value differs', () {
      final c = event(
        {'name': 'Ancien', 'city': 'Paris', 'timezone': 'Europe/Paris'},
        {'name': 'Nouveau', 'city': 'Paris', 'timezone': 'Europe/Paris'},
      ).changes;
      expect(c, hasLength(1));
      expect(c.single.field, 'Name');
      expect(c.single.before, 'Ancien');
      expect(c.single.after, 'Nouveau');
    });

    test('a creation has no "before" and a deletion no "after"', () {
      final created = event(null, {'name': 'Salle 1'}).changes.single;
      expect(created.before, '—');
      expect(created.after, 'Salle 1');
      final deleted = event({'name': 'Salle 1'}, null).changes.single;
      expect(deleted.before, 'Salle 1');
      expect(deleted.after, '—');
    });

    test('sensitive fields change visibly but never reveal their values', () {
      final c = event(
        {'password': 'old-secret', 'api_token': 'abc'},
        {'password': 'new-secret', 'api_token': 'def'},
      ).changes;
      expect(c, hasLength(2));
      for (final x in c) {
        expect(x.before, '••••');
        expect(x.after, '••••');
      }
    });

    test('booleans and snake_case are readable', () {
      final c = event({'is_primary': false}, {'is_primary': true}).changes.single;
      expect(c.field, 'Is primary');
      expect(c.before, 'non');
      expect(c.after, 'oui');
    });

    test('no stored values means no changes to show', () {
      expect(event(null, null).changes, isEmpty);
    });
  });

  group('roles', () {
    test('a role has one name everywhere', () {
      expect(RoleLabels.of('owner'), 'Direction');
      expect(RoleLabels.of('stock_manager'), 'Responsable stock');
      expect(RoleLabels.of('viewer'), 'Lecture seule');
    });

    test('every role has a description and an unknown one does not crash', () {
      for (final r in const [
        'owner',
        'admin',
        'stock_manager',
        'releaser',
        'practitioner',
        'viewer',
      ]) {
        expect(RoleLabels.describe(r), isNotEmpty);
        expect(RoleLabels.describe(r), isNot('Droits définis par le cabinet.'));
      }
      expect(RoleLabels.describe('mystery'), 'Droits définis par le cabinet.');
    });
  });

  group('contacts', () {
    test('a phone number is reduced to what a dialer understands', () {
      expect(ContactLauncher.dialable('01 42 68-00.22'), '0142680022');
      expect(ContactLauncher.dialable('+33 (0)1 42 68 00 22'), '+330142680022');
      expect(ContactLauncher.phoneUri('01 42 68 00 22').toString(),
          'tel:0142680022');
    });

    test('an e-mail and an address make valid links', () {
      expect(ContactLauncher.mailUri(' a@b.fr ').toString(), 'mailto:a@b.fr');
      final map = ContactLauncher.mapUri('12 rue de la Paix, Paris');
      expect(map.scheme, 'geo');
      expect(map.queryParameters['q'], '12 rue de la Paix, Paris');
    });
  });

  group('marks', () {
    test('initials from a name', () {
      expect(EntityMark.initialsOf('Dental Plus'), 'DP');
      expect(EntityMark.initialsOf('Marie'), 'M');
      expect(EntityMark.initialsOf('  '), '•');
      expect(EntityMark.initialsOf('Jean Pierre Martin'), 'JM');
    });
  });
}
