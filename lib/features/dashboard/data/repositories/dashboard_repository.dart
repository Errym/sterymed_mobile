import '../datasources/dashboard_remote_datasource.dart';
import '../models/dashboard_data.dart';

class DashboardRepository {
  final DashboardRemoteDatasource _remote;

  DashboardRepository(this._remote);

  Future<DashboardData> fetch() async {
    try {
      return await _remote.fetch();
    } catch (_) {
      return _placeholder();
    }
  }

  /// Temporary placeholder data until the backend ships `GET /v1/dashboard`.
  /// Shape matches [DashboardData] so the swap is a one-line change.
  DashboardData _placeholder() {
    return const DashboardData(
      greeting: 'Bonjour',
      userName: 'Admin',
      kpis: [
        DashboardKpi(
          id: 'active_cycles',
          label: 'Cycles en cours',
          value: 0,
          route: '/app/cycles',
        ),
        DashboardKpi(
          id: 'waiting_placement',
          label: 'En attente de pose',
          value: 0,
          route: '/app/prosthetic/waiting-placement',
        ),
        DashboardKpi(
          id: 'pending_alerts',
          label: 'Alertes actives',
          value: 0,
          route: '/app/alerts',
        ),
        DashboardKpi(
          id: 'today_procedures',
          label: 'Actes du jour',
          value: 0,
          route: '/app/audit',
        ),
      ],
      attention: [],
      todayCycles: [],
      recentProcedures: [],
    );
  }
}
