import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthSessionChecked extends AuthEvent {
  const AuthSessionChecked();
}

class AuthLoginSubmitted extends AuthEvent {
  final String tenantSlug;
  final String email;
  final String password;

  const AuthLoginSubmitted({
    required this.tenantSlug,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [tenantSlug, email, password];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthLogoutEverywhereRequested extends AuthEvent {
  const AuthLogoutEverywhereRequested();
}
class AuthRegisterSubmitted extends AuthEvent {
  final String tenantName;
  final String tenantSlug;
  final String ownerName;
  final String ownerEmail;
  final String password;

  const AuthRegisterSubmitted({
    required this.tenantName,
    required this.tenantSlug,
    required this.ownerName,
    required this.ownerEmail,
    required this.password,
  });

  @override
  List<Object?> get props => [
        tenantName,
        tenantSlug,
        ownerName,
        ownerEmail,
        password,
      ];
}
