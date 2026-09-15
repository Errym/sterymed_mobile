import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../shell/presentation/widgets/profile_menu.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../widgets/attention_cards.dart';
import '../widgets/kpi_row.dart';
import '../widgets/recent_procedures_card.dart';
import '../widgets/today_cycles_card.dart';

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
      context.read<DashboardCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionStore>();
    final name = session.user?['name']?.toString() ?? 'Utilisateur';
    final email = session.user?['email']?.toString() ?? '';
    final role = session.user?['role']?.toString() ?? 'staff';

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<DashboardCubit>().load(),
          child: BlocBuilder<DashboardCubit, DashboardState>(
            builder: (context, state) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      name: name,
                      email: email,
                      role: role,
                    ),
                  ),
                  if (state is DashboardLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state is DashboardLoaded) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: KpiRow(
                          kpis: state.data.kpis,
                          onTap: (route) => context.go(route),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.lg),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: AttentionCards(
                          items: state.data.attention,
                          onTap: (route) => context.go(route),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.lg),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: TodayCyclesCard(
                          cycles: state.data.todayCycles,
                          onTap: () => context.go(Routes.cycles),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.lg),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: RecentProceduresCard(
                          procedures: state.data.recentProcedures,
                          onTap: () => context.go(Routes.audit),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xxl),
                    ),
                  ] else if (state is DashboardError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            state.message,
                            style: AppTypography.body,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String email;
  final String role;

  const _Header({
    required this.name,
    required this.email,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tableau de bord', style: AppTypography.pageTitle),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Vue d\'ensemble de votre activité',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          ProfileMenu(
            displayName: name,
            email: email,
            role: role,
          ),
        ],
      ),
    );
  }
}
