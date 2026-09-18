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
    when(() => repo.login(
          tenantSlug: any(named: 'tenantSlug'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(seconds: 5));
    });

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

    // Button should be in loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
