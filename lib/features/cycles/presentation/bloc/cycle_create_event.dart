part of 'cycle_create_bloc.dart';

abstract class CycleCreateEvent extends Equatable {
  const CycleCreateEvent();
  @override
  List<Object?> get props => [];
}

class SubmitCycleCreate extends CycleCreateEvent {
  final String deviceId;
  final String? programId;
  final String? notes;
  const SubmitCycleCreate({
    required this.deviceId,
    this.programId,
    this.notes,
  });
  @override
  List<Object?> get props => [deviceId, programId, notes];
}
