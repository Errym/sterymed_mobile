import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/sync/sync_status_cubit.dart';
import '../../../../di/di.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;
  int _intent = 0;

  bool _current(int intent, Emitter<AuthState> emit) =>
      intent == _intent && !emit.isDone;
  ApiException _error(Object error) => error is ApiException
      ? error
      : error is DioException
      ? ErrorMapper.fromDio(error)
      : const ApiException(
          code: 'unknown',
          message: 'Connexion impossible. Réessayez.',
        );

  AuthBloc(this._repository) : super(const AuthInitial()) {
    on<AuthSessionChecked>(_onSessionChecked);
    on<AuthLoginSubmitted>(_onLoginSubmitted);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthSessionExpired>(_onSessionExpired);
    on<AuthLogoutEverywhereRequested>(_onLogoutEverywhere);
    on<AuthRegisterSubmitted>(_onRegisterSubmitted);
  }

  Future<void> _onSessionChecked(
    AuthSessionChecked event,
    Emitter<AuthState> emit,
  ) async {
    final intent = ++_intent;
    emit(const AuthLoading());
    try {
      final restored = await _repository.restoreSession();
      if (_current(intent, emit)) {
        emit(
          restored ? const AuthAuthenticated() : const AuthUnauthenticated(),
        );
      }
    } catch (_) {
      if (_current(intent, emit)) emit(const AuthRestoreUnavailable());
    }
  }

  Future<void> _onLoginSubmitted(
    AuthLoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final intent = ++_intent;
    emit(const AuthLoading());
    try {
      await _repository.login(
        tenantSlug: event.tenantSlug,
        email: event.email,
        password: event.password,
      );
      if (!_current(intent, emit)) return;
      unawaited(getIt<SyncStatusCubit>().refreshNow());
      emit(const AuthAuthenticated());
    } on ApiException catch (e) {
      if (!_current(intent, emit)) return;
      emit(AuthError(e));
      emit(const AuthUnauthenticated());
    } catch (e) {
      if (!_current(intent, emit)) return;
      emit(AuthError(_error(e)));
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    ++_intent;
    final revocation = _repository.logout();
    emit(const AuthUnauthenticated());
    try {
      await revocation.timeout(const Duration(seconds: 5));
    } catch (_) {
      // Backend unreachable — still wipe local state.
    }
  }

  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    if (event.generation != null && event.generation != _repository.generation) {
      return;
    }
    ++_intent;
    // Already emitting AuthUnauthenticated is a no-op if some other path
    // (e.g. an explicit logout in flight at the same moment) already
    // cleared it — still safe to clear again.
    final clear = event.generation == null
        ? _repository.clearLocalSession()
        : _repository.clearLocalSession(expectedGeneration: event.generation);
    emit(const AuthUnauthenticated());
    await clear;
  }

  Future<void> _onLogoutEverywhere(
    AuthLogoutEverywhereRequested event,
    Emitter<AuthState> emit,
  ) async {
    final intent = ++_intent;
    final revocation = _repository.logoutEverywhere();
    emit(const AuthUnauthenticated());
    try {
      await revocation.timeout(const Duration(seconds: 5));
    } catch (_) {
      if (_current(intent, emit)) {
        emit(
          const AuthError(
            ApiException(
              code: 'revocation_unconfirmed',
              message:
                  'Déconnecté sur cet appareil. La déconnexion des autres appareils n’a pas été confirmée.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _onRegisterSubmitted(
    AuthRegisterSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final intent = ++_intent;
    emit(const AuthLoading());
    try {
      await _repository.register(
        tenantName: event.tenantName,
        tenantSlug: event.tenantSlug,
        ownerName: event.ownerName,
        ownerEmail: event.ownerEmail,
        password: event.password,
      );
      if (!_current(intent, emit)) return;
      unawaited(getIt<SyncStatusCubit>().refreshNow());
      emit(const AuthAuthenticated());
    } on ApiException catch (e) {
      if (!_current(intent, emit)) return;
      emit(AuthError(e));
      emit(const AuthUnauthenticated());
    } catch (e) {
      if (!_current(intent, emit)) return;
      emit(AuthError(_error(e)));
      emit(const AuthUnauthenticated());
    }
  }
}
