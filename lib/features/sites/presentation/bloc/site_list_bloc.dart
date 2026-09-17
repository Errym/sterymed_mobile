import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/models/site_data.dart';
import '../../data/repositories/site_repository.dart';

part 'site_list_event.dart';
part 'site_list_state.dart';

class SiteListBloc extends Bloc<SiteListEvent, SiteListState> {
  final SiteRepository _repository;

  SiteListBloc(this._repository) : super(const SiteListState()) {
    on<LoadSites>(_onLoad);
    on<RefreshSites>(_onRefresh);
    on<CreateSite>(_onCreate);
  }

  Future<void> _onLoad(LoadSites e, Emitter<SiteListState> emit) async {
    emit(state.copyWith(status: SiteListStatus.loading, error: null));
    try {
      final list = await _repository.list(forceRefresh: true);
      emit(state.copyWith(status: SiteListStatus.success, sites: list));
    } on ApiException catch (ex) {
      emit(state.copyWith(status: SiteListStatus.failure, error: ex.message));
    }
  }

  Future<void> _onRefresh(RefreshSites e, Emitter<SiteListState> emit) async {
    try {
      final list = await _repository.list(forceRefresh: true);
      emit(state.copyWith(status: SiteListStatus.success, sites: list));
    } on ApiException catch (ex) {
      emit(state.copyWith(status: SiteListStatus.failure, error: ex.message));
    }
  }

  Future<void> _onCreate(CreateSite e, Emitter<SiteListState> emit) async {
    try {
      await _repository.create(
        name: e.name,
        addressLine1: e.addressLine1,
        city: e.city,
        isPrimary: e.isPrimary,
      );
      // Give the backend a moment to persist, then force refresh.
      await Future.delayed(const Duration(milliseconds: 300));
      final list = await _repository.list(forceRefresh: true);
      emit(state.copyWith(
        status: SiteListStatus.success,
        sites: list,
      ));
    } on ApiException catch (ex) {
      emit(state.copyWith(error: ex.message));
    }
  }
}
