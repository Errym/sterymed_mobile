part of 'cycle_detail_bloc.dart';

enum CycleDetailStatus { initial, loading, success, failure }

class CycleDetailState extends Equatable {
  final CycleDetailStatus status;
  final CycleData? cycle;
  final List<CycleItemData> items;
  final List<ControlTestData> controlTests;
  final List<CycleAttachmentData> attachments;
  final CycleReleaseData? release;
  final String? error;

  const CycleDetailState({
    this.status = CycleDetailStatus.initial,
    this.cycle,
    this.items = const [],
    this.controlTests = const [],
    this.attachments = const [],
    this.release,
    this.error,
  });

  CycleDetailState copyWith({
    CycleDetailStatus? status,
    CycleData? cycle,
    List<CycleItemData>? items,
    List<ControlTestData>? controlTests,
    List<CycleAttachmentData>? attachments,
    CycleReleaseData? release,
    String? error,
  }) {
    return CycleDetailState(
      status: status ?? this.status,
      cycle: cycle ?? this.cycle,
      items: items ?? this.items,
      controlTests: controlTests ?? this.controlTests,
      attachments: attachments ?? this.attachments,
      release: release ?? this.release,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props =>
      [status, cycle, items, controlTests, attachments, release, error];
}