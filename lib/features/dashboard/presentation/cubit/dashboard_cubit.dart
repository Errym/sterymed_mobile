import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/dashboard_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository _repository;

  DashboardCubit(this._repository) : super(const DashboardInitial());

  Future<void> load() async {
    emit(const DashboardLoading());
    try {
      final data = await _repository.fetch();
      emit(DashboardLoaded(data));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }
}
