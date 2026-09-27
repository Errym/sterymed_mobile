import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../../core/sync/sync_status_cubit.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/feedback/sync_status_banner.dart';
import '../widgets/bottom_nav_bar.dart';

class ShellScreen extends StatelessWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    // Each bottom-nav tab is reached via context.go(), which replaces the
    // whole stack rather than pushing — so within a tab there is usually
    // nothing left to pop, and without this PopScope the hardware back
    // button falls through to Android and exits the app outright instead
    // of returning to the Accueil tab (reproduced repeatedly on-device,
    // see docs/DEVICE_TEST_LOG.md's "Known device-testing issue"). Only
    // the Accueil tab itself allows the real pop (i.e. exits the app),
    // matching standard Android back-navigation conventions.
    final onDashboard = location.startsWith(Routes.dashboard);

    return PopScope<Object?>(
      canPop: onDashboard,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(Routes.dashboard);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundApp,
        body: Column(
          children: [
            BlocBuilder<SyncStatusCubit, SyncStatus>(
              builder: (context, state) {
                return SyncStatusBanner(
                  online: state.online,
                  pendingCount: state.pendingCount,
                  manualReviewCount: state.manualReviewCount,
                  onTap: () => context.push('/app/sync'),
                );
              },
            ),
            Expanded(child: child),
          ],
        ),
        bottomNavigationBar: BottomNavBar(currentLocation: location),
      ),
    );
  }
}
