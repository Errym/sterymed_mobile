import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/cards/kpi_card.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../shell/presentation/widgets/profile_menu.dart';
import '../../data/models/dashboard_data.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';

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
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardData data;
  final String name;
  final String email;
  final String role;
  final bool isOwner;

  const _DashboardContent({
    super.key,
    required this.data,
    required this.name,
    required this.email,
    required this.role,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    var i = 0;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AnimatedListItem(
          index: i++,
          child: _Header(
            name: name,
            email: email,
            role: role,
            greeting: data.greeting,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AnimatedListItem(index: i++, child: _KpiGrid(kpis: data.kpis)),
        const SizedBox(height: AppSpacing.lg),
        if (data.attention.isNotEmpty) ...[
          AnimatedListItem(
            index: i++,
            child: const SectionHeader(title: 'Nécessite votre attention'),
          ),
          for (final item in data.attention)
            AnimatedListItem(
              index: i++,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _AttentionTile(item: item),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
        AnimatedListItem(
          index: i++,
          child: _TodayCyclesSection(cycles: data.todayCycles),
        ),
        const SizedBox(height: AppSpacing.lg),
        AnimatedListItem(
          index: i++,
          child: SectionHeader(
            title: isOwner ? 'Centre de gouvernance' : 'Accès rapides',
          ),
        ),
        AnimatedListItem(
          index: i++,
          child: _GovernanceMenu(isOwner: isOwner),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Skeleton (loading state)
// ─────────────────────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget block({double width = double.infinity, double height = 14}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
      );
    }

    Widget card({required double height}) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: AppColors.backgroundMuted,
      highlightColor: AppColors.backgroundSubtle,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    block(width: 180, height: 22),
                    const SizedBox(height: AppSpacing.xs),
                    block(width: 140, height: 12),
                  ],
                ),
              ),
              const CircleAvatar(radius: 18, backgroundColor: Colors.white),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              mainAxisExtent: 100,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => card(height: 100),
          ),
          const SizedBox(height: AppSpacing.lg),
          block(width: 160, height: 14),
          const SizedBox(height: AppSpacing.sm),
          card(height: 140),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 4; i++) ...[
            card(height: 64),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final String greeting;

  const _Header({
    required this.name,
    required this.email,
    required this.role,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $name',
                style: AppTypography.pageTitle.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 2),
              const Text('Voici la situation du cabinet',
                  style: AppTypography.caption),
            ],
          ),
        ),
        ProfileMenu(displayName: name, email: email, role: role),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// KPI grid
// ─────────────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  final List<DashboardKpi> kpis;
  const _KpiGrid({required this.kpis});

  @override
  Widget build(BuildContext context) {
    if (kpis.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 100,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, i) {
        final k = kpis[i];
        return TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: k.value),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => KpiCard(
            label: k.label,
            value: value.toString(),
            icon: _iconFor(k.id),
            accentColor: _accentFor(k.id),
            onTap: k.route.isEmpty ? null : () => context.go(k.route),
          ),
        );
      },
    );
  }

  IconData _iconFor(String id) {
    switch (id) {
      case 'active_cycles':
        return Icons.autorenew;
      case 'pending_alerts':
        return Icons.warning_amber_outlined;
      case 'today_cycles':
        return Icons.today_outlined;
      case 'audit_events':
        return Icons.fact_check_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _accentFor(String id) {
    switch (id) {
      case 'active_cycles':
        return AppColors.brandPrimary;
      case 'pending_alerts':
        return AppColors.warning;
      case 'today_cycles':
        return AppColors.info;
      case 'audit_events':
        return AppColors.success;
      default:
        return AppColors.brandPrimary;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Attention tiles
// ─────────────────────────────────────────────────────────────────────────

class _AttentionTile extends StatelessWidget {
  final DashboardAttentionItem item;
  const _AttentionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon) = switch (item.severity) {
      'critical' => (
          AppColors.danger,
          AppColors.dangerLight,
          Icons.error_outline
        ),
      'warning' => (
          AppColors.warning,
          AppColors.warningLight,
          Icons.warning_amber_outlined
        ),
      _ => (AppColors.info, AppColors.infoLight, Icons.info_outline),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.route),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: fg,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppRadius.md),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration:
                              BoxDecoration(color: bg, shape: BoxShape.circle),
                          child: Icon(icon, color: fg, size: 16),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child:
                              Text(item.label, style: AppTypography.bodyStrong),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppColors.textTertiary, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Today's cycles
// ─────────────────────────────────────────────────────────────────────────

class _TodayCyclesSection extends StatelessWidget {
  final List<DashboardTodayCycle> cycles;
  const _TodayCyclesSection({required this.cycles});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child:
                    Text('Cycles du jour', style: AppTypography.sectionTitle),
              ),
              TextButton(
                onPressed: () => context.go(Routes.cycles),
                child: const Text('Voir tout'),
              ),
            ],
          ),
          if (cycles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(Icons.event_available_outlined,
                      color: AppColors.textTertiary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Aucun cycle aujourd\'hui.',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            for (final c in cycles)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: InkWell(
                  onTap: () => context.go(Routes.cyclesDetail(c.id)),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cycle ${c.number}',
                                  style: AppTypography.bodyStrong),
                              const SizedBox(height: 2),
                              Text(c.deviceName, style: AppTypography.caption),
                            ],
                          ),
                        ),
                        _statusBadge(c.status),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case 'released':
        return const TypeBadge(label: 'Libéré', tone: BadgeTone.green);
      case 'in_progress':
        return const TypeBadge(label: 'En cours', tone: BadgeTone.blue);
      case 'awaiting_release':
        return const TypeBadge(
            label: 'Contrôles saisis', tone: BadgeTone.yellow);
      case 'rejected':
        return const TypeBadge(label: 'Rejeté', tone: BadgeTone.red);
      case 'completed':
        return const TypeBadge(label: 'Terminé', tone: BadgeTone.orange);
      default:
        return const TypeBadge(label: 'Créé', tone: BadgeTone.gray);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Quick access / governance menu
// ─────────────────────────────────────────────────────────────────────────

class _GovernanceMenu extends StatelessWidget {
  final bool isOwner;
  const _GovernanceMenu({required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final groups = <(String, List<_MenuItem>)>[
      (
        'Opérations',
        [
          const _MenuItem('Cycles de stérilisation',
              'Suivi complet des autoclaves', Icons.autorenew, Routes.cycles),
          const _MenuItem('Stock & Catalogue', 'Niveaux, mouvements et alertes',
              Icons.inventory_2_outlined, Routes.stock),
          const _MenuItem('Lots', 'Lots, DLC et traçabilité',
              Icons.inventory_outlined, Routes.batches),
        ],
      ),
      (
        'Catalogue & Achats',
        [
          const _MenuItem('Catalogue produits', 'Consommables et références',
              Icons.category_outlined, Routes.products),
          const _MenuItem('Fournisseurs', 'Contacts et références fournisseurs',
              Icons.local_shipping_outlined, Routes.suppliers),
          const _MenuItem(
              'Commandes & Réceptions',
              'Bons de commande et réceptions',
              Icons.shopping_cart_outlined,
              Routes.purchases),
        ],
      ),
      (
        'Clinique & Conformité',
        [
          const _MenuItem(
              'Gestion des patients',
              'Fiches patients et historiques',
              Icons.people_outline,
              Routes.patients),
          const _MenuItem(
              'Non-Conformités & Rappels',
              'Incidents et quarantaines',
              Icons.warning_amber_outlined,
              Routes.nonConformities),
          const _MenuItem('Journal d\'Audit', 'Traces immuables',
              Icons.verified_user_outlined, Routes.audit),
        ],
      ),
      (
        'Administration',
        [
          if (isOwner)
            const _MenuItem('Équipe & Droits', 'Comptes du personnel',
                Icons.person_add_alt_outlined, Routes.team),
          if (isOwner)
            const _MenuItem('Sites & Espaces', 'Fauteuils et zones stériles',
                Icons.meeting_room_outlined, Routes.sites),
          if (isOwner)
            const _MenuItem('Appareils & Programmes', 'Autoclaves et presets',
                Icons.precision_manufacturing_outlined, Routes.devices),
          if (isOwner)
            const _MenuItem('Règles DLU', 'Durées limite d\'utilisation',
                Icons.timer_outlined, Routes.dluRules),
          const _MenuItem('Export Données', 'Portabilité RGPD / ARS',
              Icons.download_outlined, Routes.dataExports),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (title, items) in groups)
          if (items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                  top: AppSpacing.sm, bottom: AppSpacing.xs),
              child: Text(
                title.toUpperCase(),
                style: AppTypography.label.copyWith(
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            for (final item in items) ...[
              _ActionRow(item: item),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
      ],
    );
  }
}

class _ActionRow extends StatefulWidget {
  final _MenuItem item;
  const _ActionRow({required this.item});

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go(widget.item.route),
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimaryLight,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(widget.item.icon,
                        size: 18, color: AppColors.brandPrimary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.item.title,
                            style: AppTypography.bodyStrong),
                        const SizedBox(height: 2),
                        Text(widget.item.subtitle,
                            style: AppTypography.caption),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 20, color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  const _MenuItem(this.title, this.subtitle, this.icon, this.route);
}
