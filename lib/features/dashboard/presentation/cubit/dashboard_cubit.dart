import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/utils/error_message.dart';
import '../../data/models/dashboard_data.dart';
import '../../data/repositories/dashboard_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository _repository;
  final SessionStore _session;

  DashboardCubit(this._repository, this._session)
      : super(const DashboardInitial());

  /// Every explicit load (open, pull to refresh, retry) asks the server again:
  /// the figures are about open alerts and running cycles, so a cached answer
  /// would be exactly the stale "all clear" this screen must not show.
  Future<void> load() async {
    final current = state;
    final previous = current is DashboardLoaded ? current.data : null;
    // Keep what is on screen while refreshing instead of flashing a skeleton.
    if (previous == null) emit(const DashboardLoading());
    try {
      final data = await _repository.fetch(forceRefresh: true);
      emit(DashboardLoaded(data.copyWith(userName: _session.userName ?? '')));
    } catch (e) {
      if (previous != null) {
        // The refresh failed: keep the earlier figures, labelled as stale.
        emit(DashboardLoaded(previous.copyWith(stale: true)));
        return;
      }
      emit(DashboardError(
        e is DashboardUnavailableException ? e.toString() : ErrorMessage.from(e),
      ));
    }
  }
}
