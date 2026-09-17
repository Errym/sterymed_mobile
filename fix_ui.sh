#!/usr/bin/env bash
# =============================================================================
# SteryMed Mobile — Full UI Fixes Script
# Fixes: KPI layout, Alerts provider, Cycles create 422, Stock KPIs
# Run from project root: bash fix_ui.sh
# =============================================================================
set -euo pipefail

PROJECT_ROOT="$(pwd)"

if [[ ! -f "$PROJECT_ROOT/pubspec.yaml" ]]; then
  echo "❌  Run this from the Flutter project root (pubspec.yaml not found)."
  exit 1
fi

if ! grep -q "name: steriymed_mobile" "$PROJECT_ROOT/pubspec.yaml"; then
  echo "❌  This is not the SteryMed project."
  exit 1
fi

echo "✅  Project root: $PROJECT_ROOT"
echo "═══════════════════════════════════════════════════════════════"

# ─────────────────────────────────────────────────────────────────────────────
# FIX 1 — KpiCard (compact, 100px grid height)
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Fix 1 — KpiCard compact layout"
mkdir -p lib/shared/widgets/cards

cat > lib/shared/widgets/cards/kpi_card.dart << 'DART_EOF'
import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimaryLight,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                value,
                style: AppTypography.kpiNumber.copyWith(fontSize: 32),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
DART_EOF

echo "   ✔ kpi_card.dart"

# ─────────────────────────────────────────────────────────────────────────────
# FIX 2 — app.dart (add AlertRepository to RepositoryProvider)
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Fix 2 — Add AlertRepository to MultiRepositoryProvider"

cat > lib/app.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_status_cubit.dart';
import 'core/theme/app_theme.dart';
import 'di/di.dart';
import 'features/alerts/data/repositories/alert_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/cycles/data/repositories/cycle_repository.dart';
import 'features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'features/labels/data/repositories/label_repository.dart';
import 'features/labels/data/repositories/label_usage_repository.dart';
import 'features/patients/data/repositories/patient_repository.dart';
import 'features/stock/data/repositories/stock_repository.dart';

class SteryMedApp extends StatelessWidget {
  const SteryMedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AlertRepository>(create: (_) => getIt()),
        RepositoryProvider<LabelRepository>(create: (_) => getIt()),
        RepositoryProvider<LabelUsageRepository>(create: (_) => getIt()),
        RepositoryProvider<PatientRepository>(create: (_) => getIt()),
        RepositoryProvider<CycleRepository>(create: (_) => getIt()),
        RepositoryProvider<StockRepository>(create: (_) => getIt()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(create: (_) => getIt()),
          BlocProvider<DashboardCubit>(create: (_) => getIt()),
          BlocProvider<SyncStatusCubit>.value(value: getIt()),
        ],
        child: const _AppView(),
      ),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final router = getIt<AppRouter>().router;
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      locale: const Locale(AppConstants.defaultLocale),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
DART_EOF

echo "   ✔ app.dart"

# ─────────────────────────────────────────────────────────────────────────────
# FIX 3 — Dashboard screen (mainAxisExtent: 100 for KPI grid)
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Fix 3 — Dashboard screen KPI grid"

cat > lib/features/dashboard/presentation/screens/dashboard_screen.dart << 'DART_EOF'
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
    final isOwner = role == 'owner' || role == 'admin';

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
                    title: isOwner
                        ? 'Centre de gouvernance'
                        : 'Accès rapides',
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
              const Text(
                'Voici la situation du cabinet',
                style: AppTypography.caption,
              ),
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
      'critical' => (
          AppColors.dangerLight,
          AppColors.danger,
          Icons.error_outline
        ),
      'warning' => (
          AppColors.warningLight,
          AppColors.warning,
          Icons.warning_amber_outlined
        ),
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
                child: Text(
                  item.label,
                  style: AppTypography.bodyStrong.copyWith(color: fg),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: 18,
              ),
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
      const _MenuItem(
        'Cycles de stérilisation',
        'Suivi complet des autoclaves',
        Icons.autorenew,
        Routes.cycles,
      ),
      const _MenuItem(
        'Stock & Catalogue',
        'Produits, lots, mouvements et inventaire',
        Icons.inventory_2_outlined,
        Routes.stock,
      ),
      const _MenuItem(
        'Gestion des patients',
        'Fiches patients et historiques',
        Icons.people_outline,
        Routes.patients,
      ),
      const _MenuItem(
        'Non-Conformités & Rappels',
        'Registre des incidents et quarantaines',
        Icons.warning_amber_outlined,
        Routes.nonConformities,
      ),
      const _MenuItem(
        'Journal d\'Audit',
        'Traces immuables et événements cliniques',
        Icons.verified_user_outlined,
        Routes.audit,
      ),
      if (isOwner)
        const _MenuItem(
          'Équipe & Droits',
          'Comptes du personnel et permissions',
          Icons.person_add_alt_outlined,
          Routes.team,
        ),
      if (isOwner)
        const _MenuItem(
          'Sites & Salles',
          'Fauteuils, zones stériles et stockage',
          Icons.meeting_room_outlined,
          Routes.sites,
        ),
      const _MenuItem(
        'Export Données',
        'Portabilité RGPD / ARS',
        Icons.download_outlined,
        Routes.dataExports,
      ),
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
                child:
                    Icon(item.icon, size: 18, color: AppColors.brandPrimary),
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
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textTertiary,
              ),
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
DART_EOF

echo "   ✔ dashboard_screen.dart"

# ─────────────────────────────────────────────────────────────────────────────
# FIX 4 — Stock list KPI grid (mainAxisExtent: 100)
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Fix 4 — Stock list screen KPI grid"

cat > lib/features/stock/presentation/screens/stock_level_list_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/cards/kpi_card.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../../../shared/widgets/layout/section_header.dart';
import '../../data/repositories/stock_repository.dart';
import '../bloc/stock_level_list_bloc.dart';
import '../widgets/stock_level_tile.dart';

class StockLevelListScreen extends StatelessWidget {
  const StockLevelListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StockLevelListBloc(getIt<StockRepository>())
        ..add(const LoadStockLevels()),
      child: const _StockLevelView(),
    );
  }
}

class _StockLevelView extends StatelessWidget {
  const _StockLevelView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Stock & Stérilisation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.go(Routes.alerts),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context
                .read<StockLevelListBloc>()
                .add(const RefreshStockLevels()),
          ),
        ],
      ),
      body: BlocBuilder<StockLevelListBloc, StockLevelListState>(
        builder: (context, state) {
          if (state.status == StockLevelStatus.loading &&
              state.levels.isEmpty) {
            return const LoadingView(message: 'Chargement du stock...');
          }
          if (state.status == StockLevelStatus.failure &&
              state.levels.isEmpty) {
            return ErrorView(
              message: state.error ?? 'Erreur',
              onRetry: () => context
                  .read<StockLevelListBloc>()
                  .add(const LoadStockLevels()),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => context
                .read<StockLevelListBloc>()
                .add(const RefreshStockLevels()),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tableau de bord des stocks',
                            style: AppTypography.pageTitle),
                        const SizedBox(height: AppSpacing.md),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisSpacing: AppSpacing.sm,
                          mainAxisExtent: 100,
                          children: [
                            KpiCard(
                              label: 'Références',
                              value: state.totalRefs.toString(),
                              icon: Icons.inventory_2_outlined,
                            ),
                            KpiCard(
                              label: 'Stock faible',
                              value: state.lowCount.toString(),
                              icon: Icons.warning_amber_outlined,
                            ),
                            KpiCard(
                              label: 'DLC proche',
                              value: state.nearExpiryCount.toString(),
                              icon: Icons.timer_outlined,
                            ),
                            KpiCard(
                              label: 'Périmés',
                              value: state.expiredCount.toString(),
                              icon: Icons.cancel_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const SectionHeader(title: 'Actions rapides'),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.remove_circle_outline,
                                label: 'Sortie',
                                onTap: () => context.go(Routes.stockIssue),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.edit_outlined,
                                label: 'Ajustement',
                                onTap: () => context.go(Routes.stockAdjust),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.swap_horiz,
                                label: 'Transfert',
                                onTap: () => context.go(Routes.stockTransfer),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const SectionHeader(title: 'Catalogue'),
                        AppSearchField(
                          hint: 'Rechercher un produit, lot...',
                          onChanged: (q) => context
                              .read<StockLevelListBloc>()
                              .add(SearchStockLevels(q)),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ),
                  ),
                ),
                if (state.filtered.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      title: 'Aucun produit',
                      message: 'Le catalogue est vide.',
                      icon: Icons.inventory_2_outlined,
                    ),
                  )
                else
                  SliverPadding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    sliver: SliverList.separated(
                      itemCount: state.filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) =>
                          StockLevelTile(level: state.filtered[i]),
                    ),
                  ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xxl)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 18, color: AppColors.brandPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(label,
                  style: AppTypography.caption, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
DART_EOF

echo "   ✔ stock_level_list_screen.dart"

# ─────────────────────────────────────────────────────────────────────────────
# FIX 5 — Device model, datasource, repository (for Cycles create)
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Fix 5 — Device layer for Cycles create"
mkdir -p lib/features/cycles/data/models \
         lib/features/cycles/data/datasources \
         lib/features/cycles/data/repositories

cat > lib/features/cycles/data/models/device_data.dart << 'DART_EOF'
import 'package:equatable/equatable.dart';

class DeviceData extends Equatable {
  final String id;
  final String name;
  final String? model;
  final String? serialNumber;
  final String? status;

  const DeviceData({
    required this.id,
    required this.name,
    this.model,
    this.serialNumber,
    this.status,
  });

  factory DeviceData.fromJson(Map<String, dynamic> json) => DeviceData(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        model: json['model']?.toString(),
        serialNumber: json['serial_number']?.toString(),
        status: json['status']?.toString(),
      );

  @override
  List<Object?> get props => [id, name];
}
DART_EOF

cat > lib/features/cycles/data/datasources/device_remote_datasource.dart << 'DART_EOF'
import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../models/device_data.dart';

class DeviceRemoteDatasource {
  final Dio _dio;
  DeviceRemoteDatasource(this._dio);

  Future<List<DeviceData>> list() async {
    try {
      final res = await _dio.get(
        '/v1/devices',
        queryParameters: {'per_page': 100},
      );
      final raw = res.data;
      if (raw is! Map || raw['data'] is! List) return const [];
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => DeviceData.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
DART_EOF

cat > lib/features/cycles/data/repositories/device_repository.dart << 'DART_EOF'
import '../datasources/device_remote_datasource.dart';
import '../models/device_data.dart';

class DeviceRepository {
  final DeviceRemoteDatasource _remote;
  DeviceRepository(this._remote);

  Future<List<DeviceData>> list() => _remote.list();
}
DART_EOF

echo "   ✔ device model + datasource + repository"

# ─────────────────────────────────────────────────────────────────────────────
# FIX 6 — DI registration for DeviceRepository
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Fix 6 — Register DeviceRepository in DI"

# We append the registration to the existing features_di.dart safely.
# Using a marker to avoid duplicate registration on re-runs.

DI_FILE="lib/di/features_di.dart"

# Remove any previous block
python - << 'PYEOF' "$DI_FILE" 2>/dev/null || sed -i '/\/\/ ── Devices (added by fix_ui.sh) ──/,/^  );$/d' "$DI_FILE"
import sys, re
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()
content = re.sub(
    r"\n  // ── Devices \(added by fix_ui\.sh\) ──.*?\n  \);\n",
    "\n",
    content,
    flags=re.DOTALL,
)
with open(path, 'w') as f:
    f.write(content)
PYEOF

# Check if imports exist
if ! grep -q "device_remote_datasource.dart" "$DI_FILE"; then
  sed -i "s|import '../features/cycles/data/datasources/cycle_remote_datasource.dart';|import '../features/cycles/data/datasources/cycle_remote_datasource.dart';\nimport '../features/cycles/data/datasources/device_remote_datasource.dart';|" "$DI_FILE"
fi

if ! grep -q "device_repository.dart" "$DI_FILE"; then
  sed -i "s|import '../features/cycles/data/repositories/cycle_repository.dart';|import '../features/cycles/data/repositories/cycle_repository.dart';\nimport '../features/cycles/data/repositories/device_repository.dart';|" "$DI_FILE"
fi

# Insert the DeviceRepository registration before the final closing brace of registerFeatures
# Find the last occurrence of '  );\n}' at the end of registerFeatures and inject before it
python - << 'PYEOF' "$DI_FILE"
import sys, re
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

# Check if already registered
if 'DeviceRepository>' in content:
    print("Already registered, skipping")
    sys.exit(0)

# Find last '  );\n}' and inject before it
marker = "\n}\n"
# Find the last occurrence
idx = content.rfind(marker)
if idx == -1:
    print("Could not find closing marker", file=sys.stderr)
    sys.exit(1)

injection = """
  // ── Devices (added by fix_ui.sh) ──
  getIt.registerLazySingleton<DeviceRemoteDatasource>(
    () => DeviceRemoteDatasource(getIt<DioClient>().dio),
  );
  getIt.registerLazySingleton<DeviceRepository>(
    () => DeviceRepository(getIt<DeviceRemoteDatasource>()),
  );
"""

new_content = content[:idx] + injection + content[idx:]
with open(path, 'w') as f:
    f.write(new_content)

print("Injected DeviceRepository registration")
PYEOF

echo "   ✔ DI registration"

# ─────────────────────────────────────────────────────────────────────────────
# FIX 7 — Cycles create screen (uses real devices)
# ─────────────────────────────────────────────────────────────────────────────
echo "▶  Fix 7 — Cycles create screen with real device fetching"

cat > lib/features/cycles/presentation/screens/cycle_create_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/device_data.dart';
import '../../data/repositories/cycle_repository.dart';
import '../../data/repositories/device_repository.dart';

class CycleCreateScreen extends StatefulWidget {
  const CycleCreateScreen({super.key});

  @override
  State<CycleCreateScreen> createState() => _CycleCreateScreenState();
}

class _CycleCreateScreenState extends State<CycleCreateScreen> {
  final _notesCtrl = TextEditingController();
  List<DeviceData> _devices = [];
  String? _deviceId;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await getIt<DeviceRepository>().list();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_deviceId == null) {
      AppSnackbar.show(context, 'Sélectionnez un appareil.',
          kind: SnackKind.warning);
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<CycleRepository>().create({
        'device_id': _deviceId,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      });
      if (!mounted) return;
      AppSnackbar.show(context, 'Cycle initialisé.', kind: SnackKind.success);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.toString(), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = getIt<SessionStore>();
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Initialiser un Nouveau Cycle'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundCard,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.add_box_outlined,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cycle de Stérilisation Normé EN 13060',
                              style: AppTypography.bodyStrong,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Sélectionnez l\'appareil autoclave pour la charge.',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionLabel('APPAREIL AUTOCLAVE'),
                AppDropdown<String>(
                  value: _deviceId,
                  hint: _devices.isEmpty
                      ? 'Aucun appareil disponible'
                      : 'Sélectionner un appareil',
                  options: _devices
                      .map((d) => AppDropdownOption(
                            value: d.id,
                            label: d.name,
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _deviceId = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionLabel('OPÉRATEUR CHARGÉ DU CYCLE'),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        currentUser.userName ?? 'Utilisateur actuel',
                        style: AppTypography.bodyStrong,
                      ),
                      const Spacer(),
                      const Text('Vous', style: AppTypography.caption),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionLabel('NOTES SUR LA CHARGE (OPTIONNEL)'),
                AppTextArea(
                  controller: _notesCtrl,
                  hint:
                      'Ex : Cassettes chirurgicales Dr. Watson, sachets turbines...',
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Initialiser & Charger les Sachets',
                  icon: Icons.add_circle_outline,
                  isLoading: _submitting,
                  onPressed: _devices.isEmpty ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          letterSpacing: 0.4,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
DART_EOF

echo "   ✔ cycle_create_screen.dart"

# ─────────────────────────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅  All fixes deployed."
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "▶  Running flutter analyze..."
echo ""

flutter analyze || true

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✔  Done."
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Hot RESTART the app (press 'R' in flutter run, NOT 'r')"
echo "  2. Change your test user's role to 'owner' — see commands below"
echo "  3. Re-test all screens"
echo ""
echo "To promote your test user to owner:"
echo ""
echo "  docker exec -it steriqore-app php artisan tinker"
echo "  >>> \\DB::table('tenant_user')->where('user_id',"
echo "  >>>   App\\Models\\User::where('email','test@test.com')->first()->id)"
echo "  >>>   ->update(['role' => 'owner']);"
echo "  >>> exit"
echo ""