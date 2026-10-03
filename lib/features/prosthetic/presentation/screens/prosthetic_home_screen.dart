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
import '../../data/models/prosthetic_case_data.dart';
import '../utils/prosthetic_scopes.dart';
import '../widgets/prosthetic_case_tile.dart';
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
  late Future<List<ProstheticCaseData>> _longestWaiting;

  bool get _canManage =>
      getIt<SessionStore>().hasPermission('prosthetic_cases.manage');

  @override
  void initState() {
    super.initState();
    _future = getIt<ProstheticRepository>().dashboard(forceRefresh: true);
    _longestWaiting = _loadLongestWaiting();
  }

  /// The few cases that have waited longest since the lab returned them. A
  /// failure only hides this block: the counters above stay the truth.
  Future<List<ProstheticCaseData>> _loadLongestWaiting() async {
    try {
      final page = await getIt<ProstheticRepository>().waitingForPlacement();
      final items = [...page.items]..sort(
          (a, b) => (b.daysWaitingForPlacement ?? 0)
              .compareTo(a.daysWaitingForPlacement ?? 0),
        );
      return items.take(3).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = getIt<ProstheticRepository>().dashboard(forceRefresh: true);
      _longestWaiting = _loadLongestWaiting();
    });
    await _future;
  }

  /// Opens the list a card stands for. The card's number and the list's
  /// total come from the same server scope, so they always match.
  Future<void> _openScope(String scope) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProstheticCaseListScreen(initialScope: scope),
    ));
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _canManage;
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Travaux prothétiques',
        actions: [
          // Hidden, not disabled: a button that can never work is noise.
          if (canManage)
            IconButton(
              icon: const Icon(Icons.local_shipping_outlined),
              tooltip: 'Laboratoires',
              onPressed: () => context.push(Routes.prostheticLaboratories),
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
                _PriorityHeadline(data: d),
                const SizedBox(height: AppSpacing.md),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  // Grows with the user's text size so a card never clips its label.
                  mainAxisExtent: 112 *
                      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
                  children: [
                    _Kpi(
                      label: 'Travaux actifs',
                      value: d.activeCases,
                      icon: Icons.medical_services_outlined,
                      accent: AppColors.brandPrimary,
                      onTap: () => _openScope(ProstheticScope.active),
                    ),
                    _Kpi(
                      label: 'Chez le laboratoire',
                      value: d.atLaboratory,
                      icon: Icons.local_shipping_outlined,
                      accent: AppColors.info,
                      onTap: () => _openScope(ProstheticScope.atLaboratory),
                    ),
                    _Kpi(
                      label: 'Revenus au cabinet',
                      value: d.returnedToPractice,
                      icon: Icons.move_to_inbox_outlined,
                      accent: AppColors.warning,
                      onTap: () => _openScope(ProstheticScope.returnedToPractice),
                    ),
                    _Kpi(
                      label: 'En attente de pose',
                      value: d.waitingForPlacement,
                      icon: Icons.hourglass_bottom,
                      accent: AppColors.danger,
                      onTap: () async {
                        await context.push(Routes.prostheticWaitingPlacement);
                        if (mounted) await _refresh();
                      },
                    ),
                    _Kpi(
                      label: 'Poses aujourd\'hui',
                      value: d.placementsToday,
                      icon: Icons.event_available_outlined,
                      accent: AppColors.success,
                      onTap: () => _openScope(ProstheticScope.placementsToday),
                    ),
                    _Kpi(
                      label: 'Paiements à vérifier',
                      value: d.depositsOrBalancesDue,
                      icon: Icons.euro,
                      accent: AppColors.danger,
                      onTap: () => _openScope(ProstheticScope.paymentsDue),
                    ),
                    // The seventh widget was plain text, i.e. a dead KPI.
                    _Kpi(
                      label: 'Poses cette semaine',
                      value: d.placementsThisWeek,
                      icon: Icons.date_range_outlined,
                      accent: AppColors.success,
                      onTap: () => _openScope(ProstheticScope.placementsThisWeek),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                FutureBuilder<List<ProstheticCaseData>>(
                  future: _longestWaiting,
                  builder: (context, snap) {
                    final items = snap.data ?? const <ProstheticCaseData>[];
                    if (items.isEmpty) return const SizedBox.shrink();
                    return Column(
                      key: const Key('longest-waiting'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ATTENDENT LA POSE DEPUIS LE PLUS LONGTEMPS',
                          style: AppTypography.eyebrow,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final c in items)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: ProstheticCaseTile(
                              item: c,
                              onTap: () async {
                                await context
                                    .push(Routes.prostheticDetail(c.id));
                                if (mounted) await _refresh();
                              },
                            ),
                          ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    );
                  },
                ),
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

/// The answer to "what do I do first?" in one sentence, before any counter.
class _PriorityHeadline extends StatelessWidget {
  final ProstheticDashboardData data;
  const _PriorityHeadline({required this.data});

  @override
  Widget build(BuildContext context) {
    final waiting = data.waitingForPlacement;
    final pay = data.depositsOrBalancesDue;
    final urgent = waiting > 0 || pay > 0;
    final parts = [
      if (waiting > 0)
        '$waiting travail${waiting > 1 ? 'x attendent' : ' attend'} la pose',
      if (pay > 0)
        '$pay paiement${pay > 1 ? 's' : ''} à vérifier',
    ];
    return Container(
      key: const Key('prosthetic-priority'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: urgent ? AppColors.navyHeader : AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: urgent ? null : Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Icon(
            urgent ? Icons.hourglass_bottom : Icons.check_circle_outline,
            color: urgent ? Colors.white : AppColors.success,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  urgent ? 'À TRAITER EN PRIORITÉ' : 'TOUT EST À JOUR',
                  style: AppTypography.eyebrow.copyWith(
                    color: urgent ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  urgent
                      ? parts.join(' · ')
                      : 'Aucun travail en retard de pose ni paiement en attente.',
                  style: AppTypography.cardTitle.copyWith(
                    color: urgent ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${data.activeCases} travaux actifs · '
                  '${data.placementsToday} pose${data.placementsToday > 1 ? 's' : ''} aujourd\'hui',
                  style: AppTypography.caption.copyWith(
                    color: urgent ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
          border: Border.all(color: AppColors.hairline),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 20),
            const Spacer(),
            Text('$value',
                style: AppTypography.pageTitle.copyWith(color: AppColors.text(accent))),
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
