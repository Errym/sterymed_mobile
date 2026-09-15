import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/api_exception.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;

  AuthBloc(this._repository) : super(const AuthInitial()) {
    on<AuthSessionChecked>(_onSessionChecked);
    on<AuthLoginSubmitted>(_onLoginSubmitted);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthLogoutEverywhereRequested>(_onLogoutEverywhere);
    on<AuthRegisterSubmitted>(_onRegisterSubmitted);
  }

  Future<void> _onSessionChecked(
    AuthSessionChecked event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final restored = await _repository.restoreSession();
    emit(restored ? const AuthAuthenticated() : const AuthUnauthenticated());
  }

  Future<void> _onLoginSubmitted(
    AuthLoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _repository.login(
        tenantSlug: event.tenantSlug,
        email: event.email,
        password: event.password,
      );
      emit(const AuthAuthenticated());
    } on ApiException catch (e) {
      emit(AuthError(e));
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(ApiException(code: 'unknown', message: e.toString())));
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.logout();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onLogoutEverywhere(
    AuthLogoutEverywhereRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.logoutEverywhere();
    emit(const AuthUnauthenticated());
  }
  Future<void> _onRegisterSubmitted(
    AuthRegisterSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _repository.register(
        tenantName: event.tenantName,
        tenantSlug: event.tenantSlug,
        ownerName: event.ownerName,
        ownerEmail: event.ownerEmail,
        password: event.password,
      );
      emit(const AuthAuthenticated());
    } on ApiException catch (e) {
      emit(AuthError(e));
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(ApiException(code: 'unknown', message: e.toString())));
      emit(const AuthUnauthenticated());
    }
  }
}
