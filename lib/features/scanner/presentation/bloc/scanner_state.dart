part of 'scanner_bloc.dart';

enum ScannerStatus { initial, scanning, cooling, resolving, resolved, error }

class ScannerState extends Equatable {
  final ScannerStatus status;
  final String? lastCode;
  final String? error;
  final bool torchOn;

  const ScannerState({
    this.status = ScannerStatus.initial,
    this.lastCode,
    this.error,
    this.torchOn = false,
  });

  ScannerState copyWith({
    ScannerStatus? status,
    String? lastCode,
    String? error,
    bool? torchOn,
  }) {
    return ScannerState(
      status: status ?? this.status,
      lastCode: lastCode ?? this.lastCode,
      error: error ?? this.error,
      torchOn: torchOn ?? this.torchOn,
    );
  }

  @override
  List<Object?> get props => [status, lastCode, error, torchOn];
}