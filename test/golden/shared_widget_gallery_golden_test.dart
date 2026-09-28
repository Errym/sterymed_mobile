// Golden regression tripwire for the shared widget kit (lib/shared/widgets/).
// Renders one of each button/badge/feedback/list/card variant on a fixed
// surface — any visual regression to the shared kit fails this test.
// Reuses the existing golden_helpers.dart surface-size fixture rather than
// introducing a second, near-duplicate "golden_config.dart" helper.
//
// AppSnackbar and ConfirmationDialog are deliberately not included: both
// are overlay-triggered (ScaffoldMessenger / showDialog), not embeddable
// inline widgets, so they don't fit a static gallery layout.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/shared/widgets/badges/aging_badge.dart';
import 'package:steriymed_mobile/shared/widgets/badges/severity_badge.dart';
import 'package:steriymed_mobile/shared/widgets/badges/status_badge.dart';
import 'package:steriymed_mobile/shared/widgets/badges/type_badge.dart';
import 'package:steriymed_mobile/shared/widgets/buttons/danger_button.dart';
import 'package:steriymed_mobile/shared/widgets/buttons/ghost_button.dart';
import 'package:steriymed_mobile/shared/widgets/buttons/icon_action_button.dart';
import 'package:steriymed_mobile/shared/widgets/buttons/primary_button.dart';
import 'package:steriymed_mobile/shared/widgets/buttons/secondary_button.dart';
import 'package:steriymed_mobile/shared/widgets/cards/kpi_card.dart';
import 'package:steriymed_mobile/shared/widgets/feedback/empty_view.dart';
import 'package:steriymed_mobile/shared/widgets/feedback/error_view.dart';
import 'package:steriymed_mobile/shared/widgets/feedback/loading_view.dart';
import 'package:steriymed_mobile/shared/widgets/feedback/offline_banner.dart';
import 'package:steriymed_mobile/shared/widgets/layout/section_header.dart';
import 'package:steriymed_mobile/shared/widgets/lists/list_tile_skeleton.dart';

import '../helpers/pump_app.dart';
import 'golden_helpers.dart';

void main() {
  testWidgets('shared widget gallery matches golden', (tester) async {
    await setGoldenSurfaceSize(tester, width: 420, height: 2700);

    await pumpApp(tester, const _Gallery());
    // Not pumpAndSettle: the gallery deliberately includes two
    // indeterminate CircularProgressIndicators (the loading button and
    // LoadingView variants), which animate forever and would never settle.
    await tester.pump();

    await expectLater(
      find.byType(_Gallery),
      matchesGoldenFile('goldens/shared_widget_gallery.png'),
    );
  });
}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Buttons'),
            PrimaryButton(
              label: 'Primary',
              onPressed: () {},
              isFullWidth: false,
            ),
            const SizedBox(height: 8),
            const PrimaryButton(
              label: 'Loading',
              isLoading: true,
              isFullWidth: false,
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Secondary',
              onPressed: () {},
              isFullWidth: false,
            ),
            const SizedBox(height: 8),
            DangerButton(
              label: 'Danger',
              onPressed: () {},
              isFullWidth: false,
            ),
            const SizedBox(height: 8),
            GhostButton(label: 'Ghost', onPressed: () {}),
            const SizedBox(height: 8),
            IconActionButton(icon: Icons.more_vert, onPressed: () {}),
            const SectionHeader(title: 'Status badges'),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusBadge(label: 'Neutral', tone: StatusTone.neutral),
                StatusBadge(label: 'Success', tone: StatusTone.success),
                StatusBadge(label: 'Warning', tone: StatusTone.warning),
                StatusBadge(label: 'Danger', tone: StatusTone.danger),
                StatusBadge(label: 'Info', tone: StatusTone.info),
              ],
            ),
            const SectionHeader(title: 'Type badges'),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TypeBadge(label: 'Blue', tone: BadgeTone.blue),
                TypeBadge(label: 'Green', tone: BadgeTone.green),
                TypeBadge(label: 'Yellow', tone: BadgeTone.yellow),
                TypeBadge(label: 'Red', tone: BadgeTone.red),
                TypeBadge(label: 'Purple', tone: BadgeTone.purple),
                TypeBadge(label: 'Orange', tone: BadgeTone.orange),
                TypeBadge(label: 'Gray', tone: BadgeTone.gray),
              ],
            ),
            const SectionHeader(title: 'Aging & severity badges'),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AgingBadge(daysElapsed: 5),
                AgingBadge(daysElapsed: 10),
                AgingBadge(daysElapsed: 20),
                SeverityBadge(severity: 'critical'),
                SeverityBadge(severity: 'warning'),
                SeverityBadge(severity: 'info'),
              ],
            ),
            const SectionHeader(title: 'Feedback'),
            const OfflineBanner(),
            const SizedBox(height: 8),
            // No fixed-height wrapper: Center (used inside each of these)
            // shrink-wraps to its child under the Column's loose height
            // constraints, so a fixed SizedBox height risks overflowing
            // under flutter_test's wide fallback font.
            const EmptyView(
              title: 'Aucun élément',
              message: 'Rien à afficher ici.',
            ),
            ErrorView(message: 'Une erreur est survenue.', onRetry: () {}),
            const LoadingView(message: 'Chargement…'),
            const SectionHeader(title: 'Lists'),
            const ListTileSkeleton(),
            const SectionHeader(title: 'Cards'),
            const SizedBox(
              width: 180,
              height: 100,
              child: KpiCard(
                label: 'Exemple',
                value: '12',
                icon: Icons.inbox_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
