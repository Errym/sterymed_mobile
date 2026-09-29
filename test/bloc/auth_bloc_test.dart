import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/errors/error_codes.dart';
import 'package:steriymed_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/auth_event.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/auth_state.dart';
import 'package:steriymed_mobile/core/sync/sync_status_cubit.dart';
import 'package:steriymed_mobile/di/di.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// A no-op stand-in for the real [SyncStatusCubit]. AuthBloc calls
/// `refreshNow()` after a successful login; the real cubit needs the
/// full engine + connectivity stack, which is overkill here. This fake
/// returns a completed future and nothing else.
class _FakeSyncStatusCubit extends Mock implements SyncStatusCubit {
  @override
  Future<void> refreshNow() async {}
}

void main() {
  late MockAuthRepository repo;
  late _FakeSyncStatusCubit fakeSync;

  setUp(() async {
    repo = MockAuthRepository();
    fakeSync = _FakeSyncStatusCubit();
    // AuthBloc now calls getIt<SyncStatusCubit>().refreshNow() after a
    // successful login (Fix 1.8). Register a lightweight fake so the test
    // doesn't need to construct the real engine + connectivity chain.
    await getIt.reset();
    getIt.registerSingleton<SyncStatusCubit>(fakeSync);
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('AuthBloc', () {
    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] on successful login',
      build: () => AuthBloc(repo),
      setUp: () {
        when(() => repo.login(
              tenantSlug: any(named: 'tenantSlug'),
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async {});
      },
      act: (bloc) => bloc.add(const AuthLoginSubmitted(
        tenantSlug: 'test',
        email: 'a@b.com',
        password: 'password123',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAuthenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, error, unauthenticated] on 401',
      build: () => AuthBloc(repo),
      setUp: () {
        when(() => repo.login(
              tenantSlug: any(named: 'tenantSlug'),
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(const ApiException(
          code: ErrorCodes.unauthenticated,
          message: 'Identifiants invalides.',
          statusCode: 401,
        ));
      },
      act: (bloc) => bloc.add(const AuthLoginSubmitted(
        tenantSlug: 'test',
        email: 'a@b.com',
        password: 'wrong',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>(),
        isA<AuthUnauthenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, unauthenticated] when session check returns false',
      build: () => AuthBloc(repo),
      setUp: () {
        when(() => repo.restoreSession()).thenAnswer((_) async => false);
      },
      act: (bloc) => bloc.add(const AuthSessionChecked()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthUnauthenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] when session check returns true',
      build: () => AuthBloc(repo),
      setUp: () {
        when(() => repo.restoreSession()).thenAnswer((_) async => true);
      },
      act: (bloc) => bloc.add(const AuthSessionChecked()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAuthenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [unauthenticated] on logout',
      build: () => AuthBloc(repo),
      setUp: () {
        when(() => repo.logout()).thenAnswer((_) async {});
      },
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [unauthenticated] on logoutEvenwhere',
      build: () => AuthBloc(repo),
      setUp: () {
        when(() => repo.logoutEverywhere()).thenAnswer((_) async {});
      },
      act: (bloc) => bloc.add(const AuthLogoutEverywhereRequested()),
      expect: () => [isA<AuthUnauthenticated>()],
    );

    // The 401 → login redirect chain: ErrorInterceptor fires this event
    // for any endpoint's real UNAUTHENTICATED 401 (see
    // error_interceptor_test.dart for that half of the chain) — this half
    // proves the event clears local session state and lands on
    // AuthUnauthenticated, which GoRouterRefreshStream (wired in
    // router_di.dart) then uses to force an immediate redirect to login,
    // not just on the user's next manual navigation.
    blocTest<AuthBloc, AuthState>(
      'AuthSessionExpired clears local session (no logout API call — the '
      'token is already invalid server-side) and emits unauthenticated',
      build: () => AuthBloc(repo),
      setUp: () {
        when(() => repo.clearLocalSession()).thenAnswer((_) async {});
      },
      act: (bloc) => bloc.add(const AuthSessionExpired()),
      expect: () => [isA<AuthUnauthenticated>()],
      verify: (_) {
        verify(() => repo.clearLocalSession()).called(1);
        verifyNever(() => repo.logout());
      },
    );
  });
}
