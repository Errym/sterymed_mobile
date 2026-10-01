// Widget tests for the forgot-password screen (account recovery, R05).
// The screen asks only for the e-mail, then shows a confirmation panel that
// tells the user how to finish in the browser and come back. It resolves its
// ForgotPasswordBloc from GetIt, so a real bloc backed by a mocked
// AuthRepository is registered there. A GoRouter is provided because the
// "back to sign in" button calls context.go(Routes.login).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/errors/error_codes.dart';
import 'package:steriymed_mobile/core/router/routes.dart';
import 'package:steriymed_mobile/di/di.dart';
import 'package:steriymed_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/forgot_password_bloc.dart';
import 'package:steriymed_mobile/features/auth/presentation/screens/forgot_password_screen.dart';

import '../helpers/pump_app.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;

  setUp(() {
    repo = MockAuthRepository();
    if (getIt.isRegistered<ForgotPasswordBloc>()) {
      getIt.unregister<ForgotPasswordBloc>();
    }
    getIt.registerFactory<ForgotPasswordBloc>(() => ForgotPasswordBloc(repo));
  });

  tearDown(() {
    getIt.unregister<ForgotPasswordBloc>();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: Routes.forgotPassword,
      routes: [
        GoRoute(
          path: Routes.forgotPassword,
          builder: (_, __) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: Routes.login,
          builder: (_, __) => const Scaffold(body: Text('LOGIN STUB')),
        ),
      ],
    );
    await pumpAppWidget(tester, MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('asks only for the e-mail address (no practice identifier)', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Adresse e-mail'), findsOneWidget);
    expect(find.textContaining('Identifiant du cabinet'), findsNothing);
  });

  testWidgets(
    'submitting sends only the e-mail and shows what to do next in the browser',
    (tester) async {
      when(
        () => repo.forgotPassword(email: any(named: 'email')),
      ).thenAnswer((_) async {});

      await pumpScreen(tester);
      await tester.enterText(find.byType(TextFormField), 'dr@cabinet.fr');
      await tester.tap(find.text('Envoyer le lien'));
      await tester.pumpAndSettle();

      verify(() => repo.forgotPassword(email: 'dr@cabinet.fr')).called(1);
      expect(find.text('Vérifiez votre boîte mail'), findsOneWidget);
      expect(find.textContaining('dr@cabinet.fr'), findsOneWidget);
      expect(find.textContaining('navigateur'), findsOneWidget);
      // It must not claim the account exists.
      expect(find.textContaining('Si un compte correspond'), findsOneWidget);
    },
  );

  testWidgets('"Retour à la connexion" goes to the sign-in screen', (
    tester,
  ) async {
    when(
      () => repo.forgotPassword(email: any(named: 'email')),
    ).thenAnswer((_) async {});
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField), 'dr@cabinet.fr');
    await tester.tap(find.text('Envoyer le lien'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retour à la connexion'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN STUB'), findsOneWidget);
  });

  testWidgets('"Renvoyer l\'e-mail" asks the server again', (tester) async {
    when(
      () => repo.forgotPassword(email: any(named: 'email')),
    ).thenAnswer((_) async {});
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField), 'dr@cabinet.fr');
    await tester.tap(find.text('Envoyer le lien'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Renvoyer l\'e-mail'));
    await tester.pumpAndSettle();

    verify(() => repo.forgotPassword(email: 'dr@cabinet.fr')).called(2);
  });

  testWidgets('an invalid email blocks submission (client-side validation)', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.text('Envoyer le lien'));
    await tester.pumpAndSettle();

    expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
    verifyNever(() => repo.forgotPassword(email: any(named: 'email')));
  });

  testWidgets('a server failure surfaces the error and stays on the form', (
    tester,
  ) async {
    when(() => repo.forgotPassword(email: any(named: 'email'))).thenThrow(
      const ApiException(
        code: ErrorCodes.rateLimited,
        message: 'Trop de requêtes. Réessayez dans un instant.',
        statusCode: 429,
      ),
    );

    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField), 'dr@cabinet.fr');
    await tester.tap(find.text('Envoyer le lien'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Trop de requêtes. Réessayez dans un instant.'),
      findsOneWidget,
    );
    expect(find.text('Vérifiez votre boîte mail'), findsNothing);
    expect(find.text('LOGIN STUB'), findsNothing);
  });
}
