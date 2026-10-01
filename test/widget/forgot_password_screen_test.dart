// TASK verification (widget): the forgot-password screen fills the form,
// submits, and (a) dispatches SubmitForgotPassword to the bloc with the right
// args and (b) shows the success SnackBar. The screen resolves its
// ForgotPasswordBloc from GetIt, so we register a real bloc backed by a mocked
// AuthRepository there. A GoRouter is provided because the success path calls
// context.go(Routes.login).

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

  // A minimal 2-route GoRouter: the screen under test plus a login stub so the
  // success-path context.go(Routes.login) has somewhere to land.
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

  testWidgets(
    'filling the form and submitting calls the repository with the right args '
    'and shows the success SnackBar',
    (tester) async {
      when(() => repo.forgotPassword(
            tenantSlug: any(named: 'tenantSlug'),
            email: any(named: 'email'),
          )).thenAnswer((_) async {});

      await pumpScreen(tester);

      await tester.enterText(
          find.byType(TextFormField).at(0), 'cabinet-martin');
      await tester.enterText(find.byType(TextFormField).at(1), 'dr@cabinet.fr');
      await tester.tap(find.text('Envoyer le lien'));
      await tester.pump(); // build loading + fire async
      await tester.pump(); // settle success emission

      verify(() => repo.forgotPassword(
            tenantSlug: 'cabinet-martin',
            email: 'dr@cabinet.fr',
          )).called(1);

      expect(
        find.textContaining('e-mail de réinitialisation'),
        findsOneWidget,
      );
    },
  );

  testWidgets('an invalid email blocks submission (client-side validation)',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'cabinet-martin');
    await tester.enterText(find.byType(TextFormField).at(1), 'not-an-email');
    await tester.tap(find.text('Envoyer le lien'));
    await tester.pumpAndSettle();

    expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
    verifyNever(() => repo.forgotPassword(
          tenantSlug: any(named: 'tenantSlug'),
          email: any(named: 'email'),
        ));
  });

  testWidgets('a server failure surfaces the error SnackBar and stays put',
      (tester) async {
    when(() => repo.forgotPassword(
          tenantSlug: any(named: 'tenantSlug'),
          email: any(named: 'email'),
        )).thenThrow(const ApiException(
      code: ErrorCodes.rateLimited,
      message: 'Trop de requêtes. Réessayez dans un instant.',
      statusCode: 429,
    ));

    await pumpScreen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'cabinet-martin');
    await tester.enterText(find.byType(TextFormField).at(1), 'dr@cabinet.fr');
    await tester.tap(find.text('Envoyer le lien'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Trop de requêtes. Réessayez dans un instant.'),
      findsOneWidget,
    );
    // Did not navigate to the login stub.
    expect(find.text('LOGIN STUB'), findsNothing);
  });
}
