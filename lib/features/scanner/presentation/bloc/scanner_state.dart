part of 'scanner_bloc.dart';

enum ScannerStatus { initial, scanning, cooling, resolving, resolved, error }

class ScannerState extends Equatable {
  final ScannerStatus status;
  final String? lastCode;
  final LabelScanResult? result;
  final String? error;
  final bool torchOn;

  const ScannerState({
    this.status = ScannerStatus.initial,
    this.lastCode,
    this.result,
    this.error,
    this.torchOn = false,
  });

  ScannerState copyWith({
    ScannerStatus? status,
    String? lastCode,
    LabelScanResult? result,
    String? error,
    bool? torchOn,
    bool clearResult = false,
  }) {
    return ScannerState(
      status: status ?? this.status,
      lastCode: lastCode ?? this.lastCode,
      result: clearResult ? null : (result ?? this.result),
      error: error ?? this.error,
      torchOn: torchOn ?? this.torchOn,
    );
  }

  @override
  List<Object?> get props => [status, lastCode, result, error, torchOn];
}
