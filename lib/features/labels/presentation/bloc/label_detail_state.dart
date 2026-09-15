part of 'label_detail_bloc.dart';

enum LabelDetailStatus { initial, loading, success, failure }

class LabelDetailState extends Equatable {
  final LabelDetailStatus status;
  final LabelScanResult? result;
  final String? error;

  const LabelDetailState({
    this.status = LabelDetailStatus.initial,
    this.result,
    this.error,
  });

  LabelDetailState copyWith({
    LabelDetailStatus? status,
    LabelScanResult? result,
    String? error,
  }) {
    return LabelDetailState(
      status: status ?? this.status,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, result, error];
}
