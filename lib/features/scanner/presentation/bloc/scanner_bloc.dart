import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../labels/data/models/label_scan_result.dart';
import '../../../labels/data/repositories/label_repository.dart';

part 'scanner_event.dart';
part 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final LabelRepository _labels;
  Timer? _cooldownTimer;

  ScannerBloc(this._labels) : super(const ScannerState()) {
    on<ScanDetected>(_onScan);
    on<ScannerCooldownExpired>(_onCooldownExpired);
    on<TorchToggled>(_onTorch);
    on<ScannerReset>(_onReset);
  }

  Future<void> _onScan(ScanDetected e, Emitter<ScannerState> emit) async {
    // Allowlist, not a denylist: block re-scans during resolving AND
    // during the resolved/error/cooling display window that follows —
    // only scanning/initial are ready for a new code. Blocking just
    // {cooling, resolving} let a second scan slip through and re-fire
    // while the previous result was still on screen, since nothing ever
    // actually transitions the state to `cooling` immediately.
    if (state.status != ScannerStatus.scanning &&
        state.status != ScannerStatus.initial) {
      return;
    }
    emit(state.copyWith(
      status: ScannerStatus.resolving,
      lastCode: e.rawValue,
      error: null,
    ));
    try {
      final result = await _labels.getByCode(e.rawValue);
      emit(state.copyWith(status: ScannerStatus.resolved, result: result));
      _startCooldown();
    } on ApiException catch (ex) {
      emit(state.copyWith(status: ScannerStatus.error, error: ex.message));
      _startCooldown();
    } catch (ex) {
      emit(state.copyWith(
        status: ScannerStatus.error,
        error: 'Erreur de lecture : ${ex.toString()}',
      ));
      _startCooldown();
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(AppConfig.scanCooldown, () {
      add(const ScannerCooldownExpired());
    });
  }

  void _onCooldownExpired(ScannerCooldownExpired e, Emitter<ScannerState> emit) {
    if (state.status == ScannerStatus.resolved ||
        state.status == ScannerStatus.error) {
      emit(state.copyWith(
        status: ScannerStatus.scanning,
        clearResult: true,
      ));
    }
  }

  void _onTorch(TorchToggled e, Emitter<ScannerState> emit) {
    emit(state.copyWith(torchOn: !state.torchOn));
  }

  void _onReset(ScannerReset e, Emitter<ScannerState> emit) {
    _cooldownTimer?.cancel();
    emit(const ScannerState());
  }

  @override
  Future<void> close() {
    _cooldownTimer?.cancel();
    return super.close();
  }
}
