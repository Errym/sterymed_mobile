// Golden 1/4: login screen. Setup mirrors test/widget/login_screen_test.dart
// (same AuthBloc/MockAuthRepository wiring) — this file only adds a fixed
// surface size and a matchesGoldenFile assertion on top of that already-
// covered behavior.

@TestOn('windows')
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:steriymed_mobile/features/auth/presentation/screens/login_screen.dart';

import '../helpers/pump_app.dart';
import '../mocks/mock_repositories.dart';
import 'golden_helpers.dart';

void main() {
  testWidgets('login screen matches golden', (tester) async {
    final repo = MockAuthRepository();
    registerFallbackValue(Uri());
    await setGoldenSurfaceSize(tester);

    await pumpApp(
      tester,
      BlocProvider(
        create: (_) => AuthBloc(repo),
        child: const LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/login_screen.png'),
    );
  });
}
