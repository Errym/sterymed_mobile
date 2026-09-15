import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/label_scan_result.dart';
import '../../data/repositories/label_repository.dart';

part 'label_detail_event.dart';
part 'label_detail_state.dart';

class LabelDetailBloc extends Bloc<LabelDetailEvent, LabelDetailState> {
  final LabelRepository _repository;

  LabelDetailBloc(this._repository) : super(const LabelDetailState()) {
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
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: LabelDetailStatus.failure,
        error: e.message,
      ));
    }
  }
}
