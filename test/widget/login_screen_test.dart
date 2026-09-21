import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:steriymed_mobile/features/auth/presentation/screens/login_screen.dart';

import '../helpers/pump_app.dart';
import '../mocks/mock_repositories.dart';

void main() {
  late MockAuthRepository repo;

  setUp(() {
    repo = MockAuthRepository();
    registerFallbackValue(Uri());
  });

  testWidgets('renders all fields', (tester) async {
    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => AuthBloc(repo),
        child: const LoginScreen(),
      ),
    );
    expect(find.text('Bienvenue'), findsOneWidget);
    expect(find.text('Identifiant du cabinet'), findsOneWidget);
    expect(find.text('Adresse e-mail'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('shows validation errors on empty submit', (tester) async {
    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => AuthBloc(repo),
        child: const LoginScreen(),
      ),
    );
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.textContaining('obligatoire'), findsWidgets);
  });

  testWidgets('shows email error for invalid email', (tester) async {
    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => AuthBloc(repo),
        child: const LoginScreen(),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'not-an-email');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
  });

  testWidgets('disables submit while loading', (tester) async {
    // A Completer that's never completed keeps the bloc in its loading
    // state without scheduling a real Timer -- a Future.delayed here
    // would leave a pending timer at teardown (or, if flushed, trigger
    // post-login navigation this test's widget tree has no GoRouter for).
    final neverCompletes = Completer<void>();
    when(() => repo.login(
          tenantSlug: any(named: 'tenantSlug'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) => neverCompletes.future);

    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => AuthBloc(repo),
        child: const LoginScreen(),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'test');
    await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');

    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('fires AuthLoginSubmitted on valid input', (tester) async {
    when(() => repo.login(
          tenantSlug: any(named: 'tenantSlug'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(const ApiException(
      code: 'unauthenticated',
      message: 'Bad credentials',
    ));

    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => AuthBloc(repo),
        child: const LoginScreen(),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'test');
    await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    verify(() => repo.login(
          tenantSlug: 'test',
          email: 'a@b.com',
          password: 'password123',
        )).called(1);
  });
}
