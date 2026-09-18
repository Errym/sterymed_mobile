import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/errors/error_codes.dart';
import 'package:steriymed_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/auth_event.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/auth_state.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;

  setUp(() {
    repo = MockAuthRepository();
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
  });
}
