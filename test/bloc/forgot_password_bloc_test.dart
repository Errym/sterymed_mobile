import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/errors/error_codes.dart';
import 'package:steriymed_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/forgot_password_bloc.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/forgot_password_event.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/forgot_password_state.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;

  setUp(() {
    repo = MockAuthRepository();
  });

  group('ForgotPasswordBloc', () {
    blocTest<ForgotPasswordBloc, ForgotPasswordState>(
      'emits [loading, success] when the repository accepts the request',
      build: () => ForgotPasswordBloc(repo),
      setUp: () {
        when(
          () => repo.forgotPassword(email: any(named: 'email')),
        ).thenAnswer((_) async {});
      },
      act: (bloc) =>
          bloc.add(const SubmitForgotPassword(email: 'dr@cabinet.fr')),
      expect: () => [
        isA<ForgotPasswordLoading>(),
        isA<ForgotPasswordSuccess>(),
      ],
      verify: (_) {
        verify(() => repo.forgotPassword(email: 'dr@cabinet.fr')).called(1);
      },
    );

    blocTest<ForgotPasswordBloc, ForgotPasswordState>(
      'emits [loading, failure] with the server message on ApiException',
      build: () => ForgotPasswordBloc(repo),
      setUp: () {
        when(() => repo.forgotPassword(email: any(named: 'email'))).thenThrow(
          const ApiException(
            code: ErrorCodes.rateLimited,
            message: 'Trop de requêtes. Réessayez dans un instant.',
            statusCode: 429,
          ),
        );
      },
      act: (bloc) =>
          bloc.add(const SubmitForgotPassword(email: 'dr@cabinet.fr')),
      expect: () => [
        isA<ForgotPasswordLoading>(),
        isA<ForgotPasswordFailure>().having(
          (s) => s.message,
          'message',
          'Trop de requêtes. Réessayez dans un instant.',
        ),
      ],
    );

    blocTest<ForgotPasswordBloc, ForgotPasswordState>(
      'emits [loading, failure] on an unexpected (non-Api) error',
      build: () => ForgotPasswordBloc(repo),
      setUp: () {
        when(
          () => repo.forgotPassword(email: any(named: 'email')),
        ).thenThrow(Exception('boom'));
      },
      act: (bloc) =>
          bloc.add(const SubmitForgotPassword(email: 'dr@cabinet.fr')),
      expect: () => [
        isA<ForgotPasswordLoading>(),
        isA<ForgotPasswordFailure>(),
      ],
    );
  });
}
