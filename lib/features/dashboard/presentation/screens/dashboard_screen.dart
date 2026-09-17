import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/cards/kpi_card.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/section_header.dart';
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
    final role = session.role ?? 'staff';
    final isOwner = session.isOwner;
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<DashboardCubit>().load(),
          child: BlocBuilder<DashboardCubit, DashboardState>(
            builder: (context, state) {
              if (state is DashboardLoading) {
                return const LoadingView(
                  message: 'Chargement du tableau de bord...',
                );
              }
              if (state is DashboardError) {
                return ErrorView(
                  message: state.message,
                  onRetry: () => context.read<DashboardCubit>().load(),
                );
              }
              final data = state is DashboardLoaded ? state.data : null;
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _Header(
                    name: name,
                    email: email,
                    role: role,
                    greeting: data?.greeting ?? 'Bonjour',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _KpiGrid(data: data),
                  const SizedBox(height: AppSpacing.lg),
                  if (data != null && data.attention.isNotEmpty) ...[
                    const SectionHeader(title: 'Nécessite votre attention'),
                    for (final item in data.attention)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _AttentionTile(item: item),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  SectionHeader(
                    title: isOwner ? 'Centre de gouvernance' : 'Accès rapides',
                  ),
                  _GovernanceMenu(isOwner: isOwner),
                  const SizedBox(height: AppSpacing.xxl),
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

class _KpiGrid extends StatelessWidget {
  final DashboardData? data;
  const _KpiGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final kpis = data?.kpis ?? const <DashboardKpi>[];
    if (kpis.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }
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
        return KpiCard(
          label: k.label,
          value: k.value.toString(),
          icon: _iconFor(k.id),
          onTap: k.route.isEmpty ? null : () => context.go(k.route),
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
}

class _AttentionTile extends StatelessWidget {
  final DashboardAttentionItem item;
  const _AttentionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (item.severity) {
      'critical' => (AppColors.dangerLight, AppColors.danger, Icons.error_outline),
      'warning' => (AppColors.warningLight, AppColors.warning, Icons.warning_amber_outlined),
      _ => (AppColors.infoLight, AppColors.info, Icons.info_outline),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.route),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(item.label,
                    style: AppTypography.bodyStrong.copyWith(color: fg)),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textTertiary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _GovernanceMenu extends StatelessWidget {
  final bool isOwner;
  const _GovernanceMenu({required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final items = <_MenuItem>[
      // Operations
      const _MenuItem('Cycles de stérilisation', 'Suivi complet des autoclaves',
          Icons.autorenew, Routes.cycles),
      const _MenuItem('Stock & Catalogue', 'Niveaux, mouvements et alertes',
          Icons.inventory_2_outlined, Routes.stock),
      const _MenuItem('Lots', 'Lots, DLC et traçabilité',
          Icons.inventory_outlined, Routes.batches),
      // Catalog
      const _MenuItem('Catalogue produits', 'Consommables et références',
          Icons.category_outlined, Routes.products),
      const _MenuItem('Fournisseurs', 'Contacts et références fournisseurs',
          Icons.local_shipping_outlined, Routes.suppliers),
      const _MenuItem('Commandes & Réceptions', 'Bons de commande et réceptions',
          Icons.shopping_cart_outlined, Routes.purchases),
      // Clinical
      const _MenuItem('Gestion des patients', 'Fiches patients et historiques',
          Icons.people_outline, Routes.patients),
      const _MenuItem('Non-Conformités & Rappels', 'Incidents et quarantaines',
          Icons.warning_amber_outlined, Routes.nonConformities),
      const _MenuItem('Journal d\'Audit', 'Traces immuables',
          Icons.verified_user_outlined, Routes.audit),
      // Admin only
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
    ];

    return Column(
      children: [
        for (final item in items) ...[
          _ActionRow(item: item),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final _MenuItem item;
  const _ActionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.route),
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
                child: Icon(item.icon, size: 18, color: AppColors.brandPrimary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: AppTypography.bodyStrong),
                    const SizedBox(height: 2),
                    Text(item.subtitle, style: AppTypography.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textTertiary),
            ],
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
