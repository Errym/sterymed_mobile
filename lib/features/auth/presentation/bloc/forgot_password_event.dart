import 'package:equatable/equatable.dart';

abstract class ForgotPasswordEvent extends Equatable {
  const ForgotPasswordEvent();

  @override
  List<Object?> get props => [];
}

class SubmitForgotPassword extends ForgotPasswordEvent {
  final String tenantSlug;
  final String email;

  const SubmitForgotPassword({
    required this.tenantSlug,
    required this.email,
  });

  @override
  List<Object?> get props => [tenantSlug, email];
}
