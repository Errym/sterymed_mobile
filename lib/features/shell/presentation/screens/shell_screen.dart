import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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

    return Scaffold(
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
    );
  }
}
