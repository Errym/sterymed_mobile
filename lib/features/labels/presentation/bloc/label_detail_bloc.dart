import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/label_scan_result.dart';
import '../../data/models/label_usage_data.dart';
import '../../data/repositories/label_repository.dart';
import '../../data/repositories/label_usage_repository.dart';

part 'label_detail_event.dart';
part 'label_detail_state.dart';

class LabelDetailBloc extends Bloc<LabelDetailEvent, LabelDetailState> {
  final LabelRepository _repository;
  final LabelUsageRepository? _usageRepository;

  LabelDetailBloc(this._repository, [this._usageRepository])
      : super(const LabelDetailState()) {
    on<LoadLabel>(_onLoad);
  }

  Future<void> _onLoad(LoadLabel event, Emitter<LabelDetailState> emit) async {
    emit(state.copyWith(status: LabelDetailStatus.loading));
    try {
      final result = await _repository.getByCode(event.code);
      emit(state.copyWith(
        status: LabelDetailStatus.success,
        result: result,
      ));

      final label = result.label;
      if (_usageRepository != null && label != null) {
        emit(state.copyWith(historyLoading: true));
        try {
          final history = await _usageRepository.history(label.id);
          emit(state.copyWith(history: history, historyLoading: false));
        } catch (_) {
          // Usage history is a supplementary detail -- don't fail the
          // whole label view if it can't be fetched.
          emit(state.copyWith(historyLoading: false));
        }
      }
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: LabelDetailStatus.failure,
        error: e.message,
      ));
    }
  }
}
