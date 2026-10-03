import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/formatters/date_formatter.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/feedback/pending_changes_banner.dart';
import '../../../../shared/widgets/inputs/filter_chip_row.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/models/stock_level_data.dart';
import '../../data/repositories/stock_repository.dart';
import '../bloc/stock_level_list_bloc.dart';
import '../widgets/stock_level_style.dart';
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
    final canManage = getIt<SessionStore>().hasPermission('inventory.manage');
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Alertes',
            onPressed: () => context.openRoute(Routes.alerts),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => context
                .read<StockLevelListBloc>()
                .add(const RefreshStockLevels()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<StockLevelListBloc, StockLevelListState>(
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
                return _StockBody(state: state);
              },
            ),
          ),
          if (canManage)
            PinnedFooter(
              child: PrimaryButton(
                key: const Key('stock-new-movement'),
                label: 'Nouveau mouvement de stock',
                icon: Icons.add,
                onPressed: () => _MovementSheet.show(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _StockBody extends StatelessWidget {
  final StockLevelListState state;
  const _StockBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<StockLevelListBloc>();
    final rows = state.filtered;
    final noStockAtAll = state.levels.isEmpty;
    return RefreshIndicator(
      onRefresh: () async => bloc.add(const RefreshStockLevels()),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PendingChangesBanner(
                    resourceKey: 'stock:',
                    matchPrefix: true,
                  ),
                  _StockSearchBar(
                    query: state.query,
                    onChanged: (q) => bloc.add(SearchStockLevels(q)),
                    onScan: () =>
                        context.openRoute('${Routes.scanner}?mode=product'),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FilterChipRow<StockFilter>(
              selected: state.filter,
              onSelected: (f) =>
                  bloc.add(FilterStockLevels(f ?? StockFilter.all)),
              options: [
                FilterChipOption(
                  value: StockFilter.all,
                  icon: Icons.inventory_2_outlined,
                  label: 'Tous (${state.countFor(StockFilter.all)})',
                ),
                FilterChipOption(
                  value: StockFilter.low,
                  dotColor: AppColors.danger,
                  label: 'Stock bas (${state.countFor(StockFilter.low)})',
                ),
                FilterChipOption(
                  value: StockFilter.perishable,
                  icon: Icons.hourglass_top_outlined,
                  label:
                      'Périssables (${state.countFor(StockFilter.perishable)})',
                ),
                FilterChipOption(
                  value: StockFilter.expired,
                  dotColor: AppColors.textPrimary,
                  label: 'Périmés (${state.countFor(StockFilter.expired)})',
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedListItem(
                    index: 0,
                    child: Row(
                      children: [
                        Expanded(
                          child: _StockMetric(
                            label: 'État global',
                            value: state.healthPercent == null
                                ? '—'
                                : '${state.healthPercent} %',
                            color: _healthColor(state.healthPercent),
                            icon: Icons.verified_outlined,
                            onTap: () => bloc.add(
                              const FilterStockLevels(StockFilter.all),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _StockMetric(
                            label: 'Réappro urgent',
                            value: '${state.urgentReorderCount} réf.',
                            color: state.urgentReorderCount > 0
                                ? AppColors.danger
                                : AppColors.success,
                            icon: Icons.priority_high,
                            onTap: () => bloc.add(
                              const FilterStockLevels(StockFilter.low),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ARTICLES EN CLINIQUE',
                          style: AppTypography.eyebrow,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.swap_vert,
                            size: 14,
                            color: AppColors.brandPrimary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Tri : criticité',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
          if (rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: noStockAtAll
                  ? const EmptyView(
                      title: 'Aucun stock',
                      message:
                          'Réceptionnez une commande pour faire apparaître '
                          'vos produits ici.',
                      icon: Icons.inventory_2_outlined,
                    )
                  : EmptyView(
                      title: 'Aucun résultat',
                      message: 'Modifiez la recherche ou le filtre pour voir '
                          'd\'autres articles.',
                      icon: Icons.search_off_outlined,
                      action: OutlinedButton(
                        onPressed: () {
                          bloc.add(const FilterStockLevels(StockFilter.all));
                          bloc.add(const SearchStockLevels(''));
                        },
                        child: const Text('Réinitialiser le filtre'),
                      ),
                    ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverList.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => AnimatedListItem(
                  index: i,
                  child: StockLevelTile(
                    level: rows[i],
                    onTap: () => _StockDetailSheet.show(context, rows[i]),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }

  static Color _healthColor(int? pct) => pct == null
      ? AppColors.textTertiary
      : pct >= 90
          ? AppColors.success
          : pct >= 70
              ? AppColors.warning
              : AppColors.danger;
}

/// White search bar with a barcode shortcut on the right: scanning a product
/// code opens the product lookup instead of typing a reference. It empties
/// itself when the list's query is reset from elsewhere ("Réinitialiser").
class _StockSearchBar extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onScan;
  const _StockSearchBar({
    required this.query,
    required this.onChanged,
    required this.onScan,
  });

  @override
  State<_StockSearchBar> createState() => _StockSearchBarState();
}

class _StockSearchBarState extends State<_StockSearchBar> {
  final _controller = TextEditingController();

  @override
  void didUpdateWidget(covariant _StockSearchBar old) {
    super.didUpdateWidget(old);
    if (widget.query.isEmpty && _controller.text.isNotEmpty) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.control),
        boxShadow: AppShadows.card,
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: AppTypography.body,
        decoration: InputDecoration(
          hintText: 'Rechercher un produit, réf ou lot...',
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppColors.textSecondary,
          ),
          suffixIcon: IconButton(
            key: const Key('stock-scan-product'),
            tooltip: 'Scanner un code-barres',
            icon: const Icon(
              Icons.barcode_reader,
              color: AppColors.navyHeader,
            ),
            onPressed: widget.onScan,
          ),
        ),
      ),
    );
  }
}

class _StockMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _StockMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTypography.eyebrow,
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: AppTypography.metric.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: color),
          ),
        ],
      ),
    );
  }
}

/// What opens when a stock row is tapped: everything the server knows about
/// that line, and the movements the signed-in role may start from it.
class _StockDetailSheet extends StatelessWidget {
  final StockLevelData level;
  final bool canManage;
  const _StockDetailSheet({required this.level, required this.canManage});

  static Future<void> show(BuildContext context, StockLevelData level) {
    final canManage = getIt<SessionStore>().hasPermission('inventory.manage');
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _StockDetailSheet(level: level, canManage: canManage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = stockStatusOf(level);
    final canMove = canManage && level.batchId != null;
    final eyebrow = [
      level.reference,
      if (level.batchNumber != null) 'LOT ${level.batchNumber}',
    ].where((s) => s.isNotEmpty).join('  ·  ');
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eyebrow.isNotEmpty)
                        Text(eyebrow, style: AppTypography.eyebrow),
                      const SizedBox(height: 2),
                      Text(level.productName, style: AppTypography.sectionTitle),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(label: status.label, tone: status.tone),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${level.qty}',
                  style: AppTypography.kpiNumber.copyWith(
                    fontSize: 34,
                    color: level.isLow || level.isExpired
                        ? status.color
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    level.minThreshold > 0
                        ? '${level.unit}  /  min. ${level.minThreshold}'
                        : level.unit,
                    style: AppTypography.body,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: stockGaugeOf(level),
                minHeight: 6,
                backgroundColor: AppColors.backgroundMuted,
                valueColor: AlwaysStoppedAnimation<Color>(status.color),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FormCard(
              gap: AppSpacing.xs,
              children: [
                _DetailRow(
                  icon: Icons.place_outlined,
                  label: 'Emplacement',
                  value: level.locationName,
                ),
                if (level.batchNumber != null)
                  _DetailRow(
                    icon: Icons.qr_code_2,
                    label: 'Lot',
                    value: level.batchNumber!,
                  ),
                if (level.expiryDate != null)
                  _DetailRow(
                    icon: Icons.event_busy_outlined,
                    label: level.isExpired ? 'Périmé depuis le' : 'Expire le',
                    value: AppDateFormatter.date(level.expiryDate!),
                    color: level.isExpired
                        ? AppColors.danger
                        : level.isNearExpiry
                            ? AppColors.warning
                            : null,
                  ),
                _DetailRow(
                  icon: Icons.tag,
                  label: 'Référence',
                  value: level.reference.isEmpty ? '—' : level.reference,
                ),
                if (level.isQuarantined)
                  const _DetailRow(
                    icon: Icons.block_outlined,
                    label: 'Statut du lot',
                    value: 'En quarantaine',
                    color: AppColors.danger,
                  ),
              ],
            ),
            if (canMove) ...[
              const SizedBox(height: AppSpacing.lg),
              const Text('ACTIONS SUR CETTE LIGNE', style: AppTypography.eyebrow),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (level.qty > 0 && !level.isQuarantined) ...[
                    Expanded(
                      child: _SheetAction(
                        icon: Icons.remove_circle_outline,
                        label: 'Sortie',
                        onTap: () => _go(
                          context,
                          Routes.stockIssueFor(
                            level.batchId!,
                            locationId: level.locationId,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (level.qty > 0) ...[
                    Expanded(
                      child: _SheetAction(
                        icon: Icons.swap_horiz,
                        label: 'Transfert',
                        onTap: () => _go(
                          context,
                          Routes.stockTransferFor(
                            level.batchId!,
                            locationId: level.locationId,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: _SheetAction(
                      icon: Icons.edit_outlined,
                      label: 'Ajuster',
                      onTap: () => _go(
                        context,
                        Routes.stockAdjustFor(
                          level.batchId!,
                          locationId: level.locationId,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String route) => _closeThenOpen(context, route);
}

/// Closes the bottom sheet, then opens [route] the way a person expects
/// (a form is pushed on top of the stock tab). The router is taken *before*
/// the sheet closes: its own context is gone afterwards.
void _closeThenOpen(BuildContext sheetContext, String route) {
  final router = GoRouter.of(sheetContext);
  Navigator.of(sheetContext).pop();
  if (isTabRoute(route)) {
    router.go(route);
  } else {
    router.push(route);
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.label)),
          Flexible(
            child: Text(
              value,
              style: AppTypography.bodyStrong.copyWith(color: color),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceWell,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            children: [
              Icon(icon, color: AppColors.navyHeader),
              const SizedBox(height: 4),
              Text(label, style: AppTypography.bodyStrong),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Nouveau mouvement de stock": what kind of movement, in the clinic's words.
class _MovementSheet extends StatelessWidget {
  const _MovementSheet();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const _MovementSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    void go(String route) => _closeThenOpen(context, route);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Nouveau mouvement', style: AppTypography.sectionTitle),
            const SizedBox(height: 2),
            const Text(
              'Chaque mouvement est tracé avec votre identifiant.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            _MovementTile(
              icon: Icons.remove_circle_outline,
              title: 'Sortie de stock',
              subtitle: 'Consommer ou retirer du stock',
              onTap: () => go(Routes.stockIssue),
            ),
            _MovementTile(
              icon: Icons.swap_horiz,
              title: 'Transfert',
              subtitle: 'Déplacer entre deux emplacements',
              onTap: () => go(Routes.stockTransfer),
            ),
            _MovementTile(
              icon: Icons.edit_outlined,
              title: 'Ajustement',
              subtitle: 'Corriger un écart : casse, perte, lot retrouvé',
              onTap: () => go(Routes.stockAdjust),
            ),
            _MovementTile(
              icon: Icons.fact_check_outlined,
              title: 'Inventaire',
              subtitle: 'Compter un emplacement',
              onTap: () => go(Routes.inventory),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MovementTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.brandPrimaryLight,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Icon(icon, color: AppColors.brandPrimaryDark),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.cardTitle),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
