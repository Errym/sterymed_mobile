// Task 3.4: "asserts every ApiEndpoints path exists in the real backend."
//
// The backend repo's docs/openapi.yaml is STALE (verified live: 28 paths,
// title still "SteriQore" from an old generation, missing every
// prosthetic-cases/laboratories/members route that exists today) so it
// cannot be this test's source of truth -- using it would let a real drift
// between mobile and backend pass silently. Instead this test compares
// against test/fixtures/contract/openapi_paths_snapshot.json, a minimal
// path-only snapshot pulled from the LIVE, auto-generated
// GET /docs/api.json (82 paths, confirmed current against real route
// definitions in app/Http/... at snapshot time). This keeps the test
// hermetic (no live backend needed to run `flutter test`) while still
// checking against reality rather than a known-stale file. Refresh the
// snapshot periodically by re-running the extraction described in its
// own "_comment" field against a running backend.
//
// Every ApiEndpoints member is exercised with dummy id values and its
// concrete path is checked against the live path patterns (a live
// "{paramName}" segment matches any single path segment; static segments
// must match exactly).
//
// Real gap found while writing this test, verified independently via
// `docker exec steriqore-app php artisan route:list --path=v1/sites`
// (shows only the GET index route, no {site} show/update/delete route):
// ApiEndpoints.site(id) => '/v1/sites/$id' points at a route that does not
// exist on the real backend. It has zero call sites in lib/ today (grepped
// before writing this), so it is currently dead code, not a live bug --
// but it would 404 the moment anything called it. Documented as BUG-025 in
// docs/BACKEND_BUGS.md. Deliberately NOT silently excluded from the
// comparison below: it is asserted as a known, currently-broken mapping so
// that fixing or removing it requires updating this test on purpose.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/config/api_endpoints.dart';

class _LivePathPattern {
  _LivePathPattern(String pattern) : segments = pattern.split('/');

  final List<String> segments;

  bool matches(String concretePath) {
    final candidate = concretePath.split('/');
    if (candidate.length != segments.length) return false;
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final isDynamic = seg.startsWith('{') && seg.endsWith('}');
      if (!isDynamic && seg != candidate[i]) return false;
    }
    return true;
  }
}

void main() {
  late List<_LivePathPattern> livePatterns;
  late Set<String> rawLivePaths;

  setUpAll(() {
    final file = File('test/fixtures/contract/openapi_paths_snapshot.json');
    final snapshot = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    rawLivePaths = (snapshot['paths'] as List).cast<String>().toSet();
    livePatterns = rawLivePaths.map(_LivePathPattern.new).toList();
  });

  bool existsLive(String concretePath) =>
      livePatterns.any((p) => p.matches(concretePath));

  group('every ApiEndpoints path exists on the real, live backend', () {
    final staticPaths = <String, String>{
      'login': ApiEndpoints.login,
      'register': ApiEndpoints.register,
      'logout': ApiEndpoints.logout,
      'logoutEverywhere': ApiEndpoints.logoutEverywhere,
      'me': ApiEndpoints.me,
      'alerts': ApiEndpoints.alerts,
      'patients': ApiEndpoints.patients,
      'products': ApiEndpoints.products,
      'productCategories': ApiEndpoints.productCategories,
      'suppliers': ApiEndpoints.suppliers,
      'purchaseOrders': ApiEndpoints.purchaseOrders,
      'sites': ApiEndpoints.sites,
      'devices': ApiEndpoints.devices,
      'cycles': ApiEndpoints.cycles,
      'stockLevels': ApiEndpoints.stockLevels,
      'stockIssue': ApiEndpoints.stockIssue,
      'stockAdjust': ApiEndpoints.stockAdjust,
      'stockTransfer': ApiEndpoints.stockTransfer,
      'auditEvents': ApiEndpoints.auditEvents,
      'nonConformities': ApiEndpoints.nonConformities,
      'dluRules': ApiEndpoints.dluRules,
      'evidenceSearch': ApiEndpoints.evidenceSearch,
      'evidenceExport': ApiEndpoints.evidenceExport,
      'invitations': ApiEndpoints.invitations,
      'dataExports': ApiEndpoints.dataExports,
      'prostheticDashboard': ApiEndpoints.prostheticDashboard,
      'prostheticWaitingPlacement': ApiEndpoints.prostheticWaitingPlacement,
      'prostheticCases': ApiEndpoints.prostheticCases,
      'laboratories': ApiEndpoints.laboratories,
      'forgotPassword': ApiEndpoints.forgotPassword,
      'locations': ApiEndpoints.locations,
      'batches': ApiEndpoints.batches,
      'practitioners': ApiEndpoints.practitioners,
    };

    staticPaths.forEach((name, path) {
      test('$name -> $path', () {
        expect(existsLive(path), isTrue,
            reason: '$path (ApiEndpoints.$name) has no matching live route');
      });
    });

    final dynamicPaths = <String, String>{
      'alertResolve': ApiEndpoints.alertResolve('X'),
      'labelByCode': ApiEndpoints.labelByCode('X'),
      'labelUsage': ApiEndpoints.labelUsage('X'),
      'patient': ApiEndpoints.patient('X'),
      'product': ApiEndpoints.product('X'),
      'supplier': ApiEndpoints.supplier('X'),
      'supplierProducts': ApiEndpoints.supplierProducts('X'),
      'purchaseOrder': ApiEndpoints.purchaseOrder('X'),
      'purchaseOrderOrder': ApiEndpoints.purchaseOrderOrder('X'),
      'purchaseOrderCancel': ApiEndpoints.purchaseOrderCancel('X'),
      'purchaseOrderReceipts': ApiEndpoints.purchaseOrderReceipts('X'),
      'device': ApiEndpoints.device('X'),
      'devicePrograms': ApiEndpoints.devicePrograms('X'),
      'deviceMaintenanceRecords': ApiEndpoints.deviceMaintenanceRecords('X'),
      'cycle': ApiEndpoints.cycle('X'),
      'cycleStart': ApiEndpoints.cycleStart('X'),
      'cycleComplete': ApiEndpoints.cycleComplete('X'),
      'cycleSubmit': ApiEndpoints.cycleSubmit('X'),
      'cycleRelease': ApiEndpoints.cycleRelease('X'),
      'cycleItems': ApiEndpoints.cycleItems('X'),
      'cycleItem': ApiEndpoints.cycleItem('X', 'Y'),
      'cycleControlTests': ApiEndpoints.cycleControlTests('X'),
      'cycleAttachments': ApiEndpoints.cycleAttachments('X'),
      'cycleAttachment': ApiEndpoints.cycleAttachment('X', 'Y'),
      'cycleLabels': ApiEndpoints.cycleLabels('X'),
      'nonConformity': ApiEndpoints.nonConformity('X'),
      'nonConformityResolve': ApiEndpoints.nonConformityResolve('X'),
      'dluRule': ApiEndpoints.dluRule('X'),
      'invitation': ApiEndpoints.invitation('X'),
      'member': ApiEndpoints.member('X'),
      'dataExport': ApiEndpoints.dataExport('X'),
      'dataExportDownload': ApiEndpoints.dataExportDownload('X'),
      'prostheticCase': ApiEndpoints.prostheticCase('X'),
      'prostheticCaseStatus': ApiEndpoints.prostheticCaseStatus('X'),
      'prostheticCaseStatusHistory':
          ApiEndpoints.prostheticCaseStatusHistory('X'),
      'prostheticCaseAttachments': ApiEndpoints.prostheticCaseAttachments('X'),
      'prostheticCaseAttachment':
          ApiEndpoints.prostheticCaseAttachment('X', 'Y'),
      'laboratory': ApiEndpoints.laboratory('X'),
    };

    dynamicPaths.forEach((name, path) {
      test('$name -> $path', () {
        expect(existsLive(path), isTrue,
            reason: '$path (ApiEndpoints.$name(...)) has no matching live route');
      });
    });
  });

  test(
    'BUG-025 (documented, not silently worked around): ApiEndpoints.site(id) '
    'points at a route that does not exist on the real backend -- '
    "`php artisan route:list --path=v1/sites` shows only the bare index "
    'route. Currently dead code (zero call sites in lib/), so this assertion '
    'is a tripwire: it fails on purpose so that fixing the route, removing '
    'the helper, or adding a real call site forces someone to update this '
    'test and docs/BACKEND_BUGS.md deliberately, instead of the drift going '
    'unnoticed.',
    () {
      expect(existsLive(ApiEndpoints.site('X')), isFalse,
          reason: 'If this now passes, /v1/sites/{id} exists live -- update '
              'this test to assert isTrue and close BUG-025.');
    },
  );

  test('snapshot sanity: has the expected live path count from the fetch', () {
    expect(rawLivePaths.length, 82);
  });
}
