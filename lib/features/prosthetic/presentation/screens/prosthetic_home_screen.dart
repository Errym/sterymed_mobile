import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/prosthetic_dashboard_data.dart';
import '../../data/repositories/prosthetic_repository.dart';
import 'prosthetic_case_list_screen.dart';

/// Brief page 5: "the team should understand the practice situation in
/// less than 10 seconds" — every card opens its corresponding filtered
/// list, no dead KPI.
class ProstheticHomeScreen extends StatefulWidget {
  const ProstheticHomeScreen({super.key});

  @override
  State<ProstheticHomeScreen> createState() => _ProstheticHomeScreenState();
}

class _ProstheticHomeScreenState extends State<ProstheticHomeScreen> {
  late Future<ProstheticDashboardData> _future;

  bool get _canManage =>
      getIt<SessionStore>().hasPermission('prosthetic_cases.manage');

  @override
  void initState() {
    super.initState();
    _future = getIt<ProstheticRepository>().dashboard(forceRefresh: true);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = getIt<ProstheticRepository>().dashboard(forceRefresh: true);
    });
    await _future;
  }

  void _openFiltered(String? status) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProstheticCaseListScreen(initialStatus: status),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _canManage;
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Travaux prothétiques',
        actions: [
          IconButton(
            icon: const Icon(Icons.local_shipping_outlined),
            tooltip: canManage
                ? 'Laboratoires'
                : 'Réservé aux praticiens et administrateurs',
            onPressed: canManage
                ? () => context.push(Routes.prostheticLaboratories)
                : null,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<ProstheticDashboardData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
                       if (snap.hasError) {
              return ErrorView(
                message: ErrorMessage.from(snap.error!),
                onRetry: _refresh,
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final d = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  mainAxisExtent: 100,
                  children: [
                    _Kpi(
                      label: 'Travaux actifs',
                      value: d.activeCases,
                      icon: Icons.medical_services_outlined,
                      accent: AppColors.brandPrimary,
                      onTap: () => _openFiltered(null),
                    ),
                    _Kpi(
                      label: 'Chez le laboratoire',
                      value: d.atLaboratory,
                      icon: Icons.local_shipping_outlined,
                      accent: AppColors.info,
                      onTap: () => _openFiltered('sent_to_laboratory'),
                    ),
                    _Kpi(
                      label: 'Revenus au cabinet',
                      value: d.returnedToPractice,
                      icon: Icons.move_to_inbox_outlined,
                      accent: AppColors.warning,
                      onTap: () => _openFiltered('received_at_practice'),
                    ),
                    _Kpi(
                      label: 'En attente de pose',
                      value: d.waitingForPlacement,
                      icon: Icons.hourglass_bottom,
                      accent: AppColors.danger,
                      onTap: () =>
                          context.push(Routes.prostheticWaitingPlacement),
                    ),
                    _Kpi(
                      label: 'Poses aujourd\'hui',
                      value: d.placementsToday,
                      icon: Icons.event_available_outlined,
                      accent: AppColors.success,
                      onTap: () => _openFiltered('placement_scheduled'),
                    ),
                    _Kpi(
                      label: 'Paiements à vérifier',
                      value: d.depositsOrBalancesDue,
                      icon: Icons.euro,
                      accent: AppColors.danger,
                      onTap: () => _openFiltered(null),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Poses cette semaine : ${d.placementsThisWeek}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProstheticCaseListScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('Voir tous les travaux'),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.prostheticCreate),
              icon: const Icon(Icons.add),
              label: const Text('Nouveau dossier'),
            )
          : null,
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 20),
            const Spacer(),
            Text('$value',
                style: AppTypography.pageTitle.copyWith(color: accent)),
            Text(label,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
