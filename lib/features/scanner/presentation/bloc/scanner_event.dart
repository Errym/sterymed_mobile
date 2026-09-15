part of 'scanner_bloc.dart';

abstract class ScannerEvent extends Equatable {
  const ScannerEvent();
  @override
  List<Object?> get props => [];
}

class ScanDetected extends ScannerEvent {
  final String rawValue;
  const ScanDetected(this.rawValue);
  @override
  List<Object> get props => [rawValue];
}

class ScannerCooldownExpired extends ScannerEvent {
  const ScannerCooldownExpired();
}

class TorchToggled extends ScannerEvent {
  const TorchToggled();
}

class ScannerReset extends ScannerEvent {
  const ScannerReset();
}
