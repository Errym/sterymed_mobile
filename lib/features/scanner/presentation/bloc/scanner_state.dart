part of 'scanner_bloc.dart';

enum ScannerStatus { initial, scanning, cooling, resolving, resolved, error }

class ScannerState extends Equatable {
  final ScannerStatus status;
  final String? lastCode;
  final LabelScanResult? result;
  final String? error;
  final String? errorCode;
  final bool torchOn;

  const ScannerState({
    this.status = ScannerStatus.initial,
    this.lastCode,
    this.result,
    this.error,
    this.errorCode,
    this.torchOn = false,
  });

  ScannerState copyWith({
    ScannerStatus? status,
    String? lastCode,
    LabelScanResult? result,
    String? error,
    bool clearError = false,
    String? errorCode,
    bool clearErrorCode = false,
    bool? torchOn,
    bool clearResult = false,
  }) {
    return ScannerState(
      status: status ?? this.status,
      lastCode: lastCode ?? this.lastCode,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      errorCode: clearErrorCode ? null : (errorCode ?? this.errorCode),
      torchOn: torchOn ?? this.torchOn,
    );
  }

  @override
  List<Object?> get props =>
      [status, lastCode, result, error, errorCode, torchOn];
}
