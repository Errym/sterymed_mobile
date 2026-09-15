import '../models/dashboard_data.dart';

class DashboardRemoteDatasource {
  const DashboardRemoteDatasource();

  /// Fetch dashboard aggregates.
  ///
  /// The backend endpoint `GET /v1/dashboard` is not shipped yet, so this
  /// throws [DashboardNotAvailableException]. The repository catches it and
  /// falls back to placeholder data. When the endpoint lands:
  ///
  ///   1. Add a `Dio` field back to this class (constructor injection).
  ///   2. Replace the `throw` with the real GET.
  ///   3. Wire it in `lib/di/features_di.dart`.
  ///
  /// The [DashboardData] model already matches the planned API shape, so
  /// nothing else changes.
  Future<DashboardData> fetch() async {
    throw const DashboardNotAvailableException();
  }
}

class DashboardNotAvailableException implements Exception {
  const DashboardNotAvailableException();
}
