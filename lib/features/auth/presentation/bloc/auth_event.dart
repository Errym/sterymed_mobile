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

/// Fired by the network layer (`ErrorInterceptor`) the moment any endpoint
/// returns a real `UNAUTHENTICATED` 401 — the token is already invalid
/// server-side, so unlike [AuthLogoutRequested] this does not call the
/// logout endpoint (that would just be a second, pointless 401).
class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
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
