import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';

part 'scanner_event.dart';
part 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  Timer? _cooldownTimer;

  ScannerBloc() : super(const ScannerState()) {
    on<ScanDetected>(_onScanDetected);
    on<ScannerCooldownExpired>(_onCooldownExpired);
    on<TorchToggled>(_onTorchToggled);
    on<ScannerReset>(_onReset);
  }

  void _onScanDetected(ScanDetected event, Emitter<ScannerState> emit) {
    if (state.status == ScannerStatus.cooling ||
        state.status == ScannerStatus.resolving) {
      return;
    }
    emit(state.copyWith(
      status: ScannerStatus.cooling,
      lastCode: event.rawValue,
      error: null,
    ));
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(AppConfig.scanCooldown, () {
      add(const ScannerCooldownExpired());
    });
  }

  void _onCooldownExpired(
    ScannerCooldownExpired event,
    Emitter<ScannerState> emit,
  ) {
    if (state.status == ScannerStatus.cooling) {
      emit(state.copyWith(status: ScannerStatus.resolved));
    }
  }

  void _onTorchToggled(TorchToggled event, Emitter<ScannerState> emit) {
    emit(state.copyWith(torchOn: !state.torchOn));
  }

  void _onReset(ScannerReset event, Emitter<ScannerState> emit) {
    _cooldownTimer?.cancel();
    emit(const ScannerState());
  }

  @override
  Future<void> close() {
    _cooldownTimer?.cancel();
    return super.close();
  }
}
