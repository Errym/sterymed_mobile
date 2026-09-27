part of 'label_detail_bloc.dart';

enum LabelDetailStatus { initial, loading, success, failure }

class LabelDetailState extends Equatable {
  final LabelDetailStatus status;
  final LabelScanResult? result;
  final String? error;
  final String? errorCode;
  final List<LabelUsageData> history;
  final bool historyLoading;

  const LabelDetailState({
    this.status = LabelDetailStatus.initial,
    this.result,
    this.error,
    this.errorCode,
    this.history = const [],
    this.historyLoading = false,
  });

  LabelDetailState copyWith({
    LabelDetailStatus? status,
    LabelScanResult? result,
    String? error,
    String? errorCode,
    List<LabelUsageData>? history,
    bool? historyLoading,
  }) {
    return LabelDetailState(
      status: status ?? this.status,
      result: result ?? this.result,
      error: error ?? this.error,
      errorCode: errorCode ?? this.errorCode,
      history: history ?? this.history,
      historyLoading: historyLoading ?? this.historyLoading,
    );
  }

  @override
  List<Object?> get props =>
      [status, result, error, errorCode, history, historyLoading];
}
