import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/router/guards/role_guard.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/role_labels.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../shell/presentation/widgets/profile_menu.dart';
import '../../data/models/dashboard_data.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';

part 'dashboard_parts/dashboard_top.dart';
part 'dashboard_parts/dashboard_content.dart';
part 'dashboard_parts/dashboard_kpis.dart';
part 'dashboard_parts/dashboard_attention.dart';
part 'dashboard_parts/dashboard_modules.dart';
part 'dashboard_parts/dashboard_insights.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DashboardCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionStore>();
    final name = session.userName ?? 'Utilisateur';
    final email = session.userEmail ?? '';
    final role = session.role ?? 'Aucun rôle';
    final isOwner = session.isOwner;

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(name: name, email: email, role: role),
            Expanded(
              child: BlocBuilder<DashboardCubit, DashboardState>(
                builder: (context, state) {
                  if (state is DashboardError) {
                    return ErrorView(
                      message: state.message,
                      onRetry: () => context.read<DashboardCubit>().load(),
                    );
                  }

                  final data = state is DashboardLoaded ? state.data : null;

                  return RefreshIndicator(
                    onRefresh: () => context.read<DashboardCubit>().load(),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: data == null
                          ? const _DashboardSkeleton(key: ValueKey('skeleton'))
                          : _DashboardContent(
                              key: const ValueKey('content'),
                              data: data,
                              name: name,
                              email: email,
                              role: role,
                              isOwner: isOwner,
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
