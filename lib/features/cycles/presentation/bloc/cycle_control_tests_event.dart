part of 'cycle_control_tests_bloc.dart';

abstract class CycleControlTestsEvent extends Equatable {
  const CycleControlTestsEvent();
  @override
  List<Object?> get props => [];
}

class LoadControlTests extends CycleControlTestsEvent {
  const LoadControlTests();
}

class AddControlTest extends CycleControlTestsEvent {
  final Map<String, dynamic> payload;
  const AddControlTest(this.payload);
  @override
  List<Object?> get props => [payload];
}
