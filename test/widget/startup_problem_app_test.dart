import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/bootstrap.dart';

void main() {
  testWidgets('startup problem screen explains and promises no data loss', (
    tester,
  ) async {
    await tester.pumpWidget(const StartupProblemApp());
    expect(find.textContaining('vérification'), findsOneWidget);
    expect(find.textContaining('pas été supprimées'), findsOneWidget);
  });
}
