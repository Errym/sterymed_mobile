import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/session_store.dart';
import '../../data/repositories/dashboard_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository _repository;
  final SessionStore _session;

  DashboardCubit(this._repository, this._session)
      : super(const DashboardInitial());

  Future<void> load() async {
    emit(const DashboardLoading());
    try {
      final data = await _repository.fetch();
      emit(DashboardLoaded(data.copyWith(userName: _session.userName ?? '')));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }
}
