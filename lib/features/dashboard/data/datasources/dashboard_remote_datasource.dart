import 'package:dio/dio.dart';

import '../../../../core/config/api_endpoints.dart';
import '../models/dashboard_data.dart';

class DashboardRemoteDatasource {
  final Dio _dio;
  const DashboardRemoteDatasource(this._dio);

  Future<DashboardData> fetch() async {
    final results = await Future.wait<Object?>([
      _safeGet(ApiEndpoints.cycles, {'per_page': 50}),
      _safeGet(ApiEndpoints.alerts, {'resolved': false, 'per_page': 50}),
      _safeGet(ApiEndpoints.auditEvents, {'per_page': 20}),
    ]);

    final cycles = _list(results[0]);
    final alerts = _list(results[1]);
    final audit = _list(results[2]);

    final now = DateTime.now();
    final activeCycles = cycles
        .where((c) => c['status'] != 'released' && c['status'] != 'rejected')
        .length;

    final todayCycles = cycles.where((c) {
      final t = DateTime.tryParse(c['created_at']?.toString() ?? '');
      return t != null &&
          t.year == now.year &&
          t.month == now.month &&
          t.day == now.day;
    }).toList();

    return DashboardData(
      greeting: _greeting(now),
      userName: '',
      kpis: [
        DashboardKpi(
          id: 'active_cycles',
          label: 'Cycles en cours',
          value: activeCycles,
          route: '/app/cycles',
        ),
        DashboardKpi(
          id: 'pending_alerts',
          label: 'Alertes actives',
          value: alerts.length,
          route: '/app/alerts',
        ),
        DashboardKpi(
          id: 'today_cycles',
          label: 'Cycles du jour',
          value: todayCycles.length,
          route: '/app/cycles',
        ),
        DashboardKpi(
          id: 'audit_events',
          label: 'Événements récents',
          value: audit.length,
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
          number: c['number']?.toString() ?? '',
          deviceName: c['device_name']?.toString() ?? '',
          status: c['status']?.toString() ?? '',
        );
      }).toList(),
      recentProcedures: audit.take(5).map((e) {
        return DashboardRecentProcedure(
          id: e['id']?.toString() ?? '',
          label: e['action']?.toString() ?? '',
          patientReference: e['subject_id']?.toString() ?? '',
          usedAt: e['occurred_at']?.toString() ?? '',
        );
      }).toList(),
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
