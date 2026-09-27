// Task 2 (test coverage completion). Was an empty stub. SyncStatusBanner is
// a pure StatelessWidget (no bloc/repository/getIt dependency) — this
// covers all 4 branches of its priority logic (hidden, manual review,
// offline, online-pending) plus the tap affordance.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/shared/widgets/feedback/sync_status_banner.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('hides entirely when online with nothing pending',
      (tester) async {
    await pumpApp(
      tester,
      const SyncStatusBanner(online: true, pendingCount: 0),
    );

    expect(find.byType(SyncStatusBanner), findsOneWidget);
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.text('Hors ligne'), findsNothing);
    expect(find.byIcon(Icons.sync), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets(
    'manual-review takes priority over online/offline state and shows the '
    'count',
    (tester) async {
      await pumpApp(
        tester,
        const SyncStatusBanner(
          online: false,
          pendingCount: 2,
          manualReviewCount: 3,
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('3 élément(s) à vérifier'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    },
  );

  testWidgets('offline with nothing pending shows just "Hors ligne"',
      (tester) async {
    await pumpApp(
      tester,
      const SyncStatusBanner(online: false, pendingCount: 0),
    );

    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.text('Hors ligne'), findsOneWidget);
  });

  testWidgets('offline with pending items appends the pending count',
      (tester) async {
    await pumpApp(
      tester,
      const SyncStatusBanner(online: false, pendingCount: 4),
    );

    expect(find.text('Hors ligne — 4 en attente'), findsOneWidget);
  });

  testWidgets('online with pending items shows the sync icon and count',
      (tester) async {
    await pumpApp(
      tester,
      const SyncStatusBanner(online: true, pendingCount: 5),
    );

    expect(find.byIcon(Icons.sync), findsOneWidget);
    expect(find.text('5 synchronisation(s) en attente'), findsOneWidget);
  });

  testWidgets('shows a chevron and is tappable when onTap is provided',
      (tester) async {
    var tapped = false;
    await pumpApp(
      tester,
      SyncStatusBanner(
        online: false,
        pendingCount: 1,
        onTap: () => tapped = true,
      ),
    );

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });

  testWidgets('shows no chevron when onTap is null', (tester) async {
    await pumpApp(
      tester,
      const SyncStatusBanner(online: false, pendingCount: 1),
    );

    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });
}
