// Phase 4 (C02): the evidence behind a cycle can be opened, and a failure is
// stated and recoverable (a fresh signed link), never an empty picture.

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/features/cycles/data/models/cycle_attachment_data.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/cycle_repository.dart';
import 'package:steriymed_mobile/features/cycles/presentation/screens/attachment_viewer_screen.dart';

import '../helpers/pump_app.dart';

class _MockRepo extends Mock implements CycleRepository {}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    if (GetIt.instance.isRegistered<CycleRepository>()) {
      GetIt.instance.unregister<CycleRepository>();
    }
    GetIt.instance.registerSingleton<CycleRepository>(repo);
  });

  tearDown(() => GetIt.instance.unregister<CycleRepository>());

  testWidgets('a PDF offers to open the file', (tester) async {
    await pumpApp(
      tester,
      const AttachmentViewerScreen(
        cycleId: 'c1',
        attachment: CycleAttachmentData(
          id: 'a1',
          url: 'http://localhost/x.pdf',
          fileName: 'rapport.pdf',
          mimeType: 'application/pdf',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('rapport.pdf'), findsWidgets);
    expect(find.text('Ouvrir le fichier'), findsOneWidget);
  });

  testWidgets('an image that cannot load says so and offers a retry', (
    tester,
  ) async {
    when(() => repo.listAttachments(any())).thenAnswer(
      (_) async => const [
        CycleAttachmentData(
          id: 'a1',
          url: 'http://localhost/fresh.png',
          fileName: 'photo.png',
          mimeType: 'image/png',
        ),
      ],
    );
    await pumpApp(
      tester,
      const AttachmentViewerScreen(
        cycleId: 'c1',
        attachment: CycleAttachmentData(
          id: 'a1',
          url: 'http://localhost/expired.png',
          fileName: 'photo.png',
          mimeType: 'image/png',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Impossible d\'afficher l\'image'),
      findsOneWidget,
    );
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    verify(() => repo.listAttachments('c1')).called(1);
  });
}
