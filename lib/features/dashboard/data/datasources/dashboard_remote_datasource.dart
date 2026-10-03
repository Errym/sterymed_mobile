import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../../../history/data/models/audit_event_data.dart';
import '../../../stock/data/models/stock_level_data.dart';
import '../models/dashboard_data.dart';

/// Every dashboard request failed: there is nothing honest to show.
class DashboardUnavailableException implements Exception {
  const DashboardUnavailableException();
  @override
  String toString() =>
      'Le tableau de bord est indisponible. Vérifiez la connexion et réessayez.';
}

class DashboardRemoteDatasource {
  final Dio _dio;

  /// Whether the signed-in user holds a permission. When given, the screen
  /// only asks for what the role may see (a viewer is not told that the audit
  /// log is "unavailable" - it simply is not theirs). When null, every
  /// section is requested, which is what the unit tests rely on.
  final bool Function(String permission)? _can;

  const DashboardRemoteDatasource(this._dio, [this._can]);

  bool _allowed(String permission) {
    final can = _can;
    return can == null || can(permission);
  }

  /// True only when permissions are known AND granted: the role-specific
  /// sections are never requested without that knowledge.
  bool _granted(String permission) {
    final can = _can;
    return can != null && can(permission);
  }

  /// Stands in for a request that was deliberately not made.
  static final Future<Object?> _skipped = Future<Object?>.value(null);

  Future<DashboardData> fetch() async {
    final canCycles = _allowed('cycles.view');
    final canAlerts = _allowed('alerts.view');
    final canAudit = _allowed('audit.view');
    final canStock = _granted('inventory.view');
    final canPurchases = _granted('purchasing.view');
    final canProsthetic = _granted('prosthetic_cases.view');

    final results = await Future.wait<Object?>([
      canCycles ? _safeGet(ApiEndpoints.cycles, {'limit': 50}) : _skipped,
      // `state` (open/resolved) is the real backend filter — `resolved`
      // was silently ignored, so this used to also fetch resolved alerts
      // and count them as active (BUG-014-class mismatch).
      canAlerts
          ? _safeGet(
              ApiEndpoints.alerts, {'filter[state]': 'open', 'limit': 50})
          : _skipped,
      canAudit ? _safeGet(ApiEndpoints.auditEvents, {'limit': 20}) : _skipped,
      _safeGet(ApiEndpoints.devices, {'limit': 50}),
      canStock ? _safeGet(ApiEndpoints.stockLevels, {'limit': 200}) : _skipped,
      canPurchases
          ? _safeGet(ApiEndpoints.purchaseOrders, {'limit': 50})
          : _skipped,
      canProsthetic
          ? _safeGet(ApiEndpoints.prostheticDashboard, const {})
          : _skipped,
    ]);

    // A request that failed is NOT an empty list. Counting it as zero would
    // tell a clinic "no open alerts" when the truth is "could not check".
    // A section the role may not see was never requested: not a failure.
    final unavailable = <String>{
      if (canCycles && results[0] == null) 'cycles',
      if (canAlerts && results[1] == null) 'alerts',
      if (canAudit && results[2] == null) 'audit',
    };
    final requested = [canCycles, canAlerts, canAudit].where((b) => b).length;
    if (requested > 0 && unavailable.length == requested) {
      throw const DashboardUnavailableException();
    }

    final cycles = _list(results[0]);
    final alerts = _list(results[1]);
    final audit = _list(results[2]);
    final devices = _list(results[3]);
    final deviceNames = {
      for (final d in devices)
        d['id']?.toString() ?? '': d['name']?.toString() ?? '',
    };

    final now = DateTime.now();
    final activeCycles = cycles
        .where((c) => c['status'] != 'released' && c['status'] != 'rejected')
        .length;

    // Cycle has no `created_at` field at all — `started_at` is the
    // closest real proxy for "happened today" (a still-draft cycle with
    // no started_at genuinely hasn't done anything today yet).
    final todayCycles = cycles.where((c) {
      final t = DateTime.tryParse(c['started_at']?.toString() ?? '');
      return t != null &&
          t.year == now.year &&
          t.month == now.month &&
          t.day == now.day;
    }).toList();

    return DashboardData(
      greeting: _greeting(now),
      userName: '',
      unavailable: unavailable,
      fetchedAt: now,
      insights: _insights(
        cycles: cycles,
        canCycles: canCycles && !unavailable.contains('cycles'),
        stock: canStock ? results[4] : null,
        purchases: canPurchases ? results[5] : null,
        prosthetic: canProsthetic ? results[6] : null,
        wantStock: canStock,
        wantPurchases: canPurchases,
        wantProsthetic: canProsthetic,
        now: now,
      ),
      kpis: [
        if (canCycles)
        DashboardKpi(
          id: 'active_cycles',
          label: 'Cycles en cours',
          value: unavailable.contains('cycles') ? null : activeCycles,
          approximate: _hasMore(results[0]),
          route: '/app/cycles',
        ),
        if (canAlerts)
        DashboardKpi(
          id: 'pending_alerts',
          label: 'Alertes actives',
          value: unavailable.contains('alerts') ? null : alerts.length,
          approximate: _hasMore(results[1]),
          route: '/app/alerts',
        ),
        if (canCycles)
        DashboardKpi(
          id: 'today_cycles',
          label: 'Cycles du jour',
          value: unavailable.contains('cycles') ? null : todayCycles.length,
          approximate: _hasMore(results[0]),
          route: '/app/cycles',
        ),
        if (canAudit)
        DashboardKpi(
          id: 'audit_events',
          label: 'Événements récents',
          value: unavailable.contains('audit') ? null : audit.length,
          approximate: _hasMore(results[2]),
          route: '/app/audit',
        ),
      ],
      attention: alerts.take(3).map((a) {
        return DashboardAttentionItem(
          id: a['id']?.toString() ?? '',
          label: a['message']?.toString() ?? 'Alerte',
          severity: a['severity']?.toString() ?? 'info',
          route: '/app/alerts',
        );
      }).toList(),
      todayCycles: todayCycles.take(5).map((c) {
        return DashboardTodayCycle(
          id: c['id']?.toString() ?? '',
          number: c['cycle_number']?.toString() ?? '',
          deviceName: deviceNames[c['device_id']?.toString()] ?? '',
          status: c['status']?.toString() ?? '',
        );
      }).toList(),
      recentProcedures: audit.take(5).map((e) {
        return DashboardRecentProcedure(
          id: e['id']?.toString() ?? '',
          label: AuditEventData.actionLabels[e['action']?.toString()] ??
              (e['action']?.toString() ?? ''),
          patientReference: e['subject_id']?.toString() ?? '',
          usedAt: e['occurred_at']?.toString() ?? '',
          actor: e['actor_label_snapshot']?.toString() ?? '',
        );
      }).toList(),
    );
  }

  /// Turns the role-gated raw answers into figures. A section that was asked
  /// for but answered nothing is reported as unavailable, never as zero.
  DashboardInsights _insights({
    required List<Map<String, dynamic>> cycles,
    required bool canCycles,
    required Object? stock,
    required Object? purchases,
    required Object? prosthetic,
    required bool wantStock,
    required bool wantPurchases,
    required bool wantProsthetic,
    required DateTime now,
  }) {
    final unavailable = <String>{};

    StockInsight? stockInsight;
    if (wantStock) {
      if (stock == null) {
        unavailable.add('stock');
      } else {
        // The same parser and the same rules as the Stock screen, so the
        // home figures can never disagree with the list they open.
        final rows = _list(stock).map(StockLevelData.fromJson).toList();
        stockInsight = StockInsight(
          rows: rows.length,
          healthy: rows.where((r) => !r.isLow && !r.isExpired).length,
          low: rows.where((r) => r.isLow).length,
          expired: rows.where((r) => r.isExpired).length,
          nearExpiry: rows.where((r) => r.isNearExpiry).length,
          partial: _hasMore(stock),
        );
      }
    }

    PurchaseInsight? purchaseInsight;
    if (wantPurchases) {
      if (purchases == null) {
        unavailable.add('purchases');
      } else {
        final open = _list(purchases).where((o) {
          final s = o['status']?.toString();
          return s == 'ordered' || s == 'partially_received';
        }).toList();
        final late = open.where((o) {
          final d = DateTime.tryParse(o['expected_at']?.toString() ?? '');
          return d != null && d.isBefore(DateTime(now.year, now.month, now.day));
        }).length;
        purchaseInsight = PurchaseInsight(toReceive: open.length, late: late);
      }
    }

    ProstheticInsight? prostheticInsight;
    if (wantProsthetic) {
      final raw = prosthetic is Map
          ? (prosthetic['data'] is Map ? prosthetic['data'] as Map : prosthetic)
          : null;
      if (raw == null) {
        unavailable.add('prosthetic');
      } else {
        int n(String k) => (raw[k] as num?)?.toInt() ?? 0;
        prostheticInsight = ProstheticInsight(
          active: n('active_cases'),
          atLaboratory: n('at_laboratory'),
          returned: n('returned_to_practice'),
          waitingForPlacement: n('waiting_for_placement'),
          placementsToday: n('placements_today'),
          placementsThisWeek: n('placements_this_week'),
          paymentsDue: n('deposits_or_balances_due'),
        );
      }
    }

    return DashboardInsights(
      stock: stockInsight,
      purchases: purchaseInsight,
      prosthetic: prostheticInsight,
      awaitingRelease: canCycles
          ? cycles.where((c) => c['status'] == 'awaiting_release').length
          : null,
      unavailable: unavailable,
    );
  }

  Future<Object?> _safeGet(String path, Map<String, dynamic> query) async {
    try {
      final res = await _dio.get(path, queryParameters: query);
      return res.data;
    } on DioException {
      return null;
    }
  }

  /// The server had another page: the counted rows are not all of them.
  bool _hasMore(Object? data) {
    if (data is! Map) return false;
    final meta = data['meta'];
    return meta is Map && meta['next_cursor'] != null;
  }

  List<Map<String, dynamic>> _list(Object? data) {
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    return const [];
  }

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }
}
