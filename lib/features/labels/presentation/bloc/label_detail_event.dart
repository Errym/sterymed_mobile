part of 'label_detail_bloc.dart';

abstract class LabelDetailEvent extends Equatable {
  const LabelDetailEvent();
  @override
  List<Object?> get props => [];
}

class LoadLabel extends LabelDetailEvent {
  final String code;
  const LoadLabel(this.code);
  @override
  List<Object> get props => [code];
}
