import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/formatters/date_formatter.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/inputs/filter_chip_row.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/list_tile_skeleton.dart';
import '../../data/models/batch_data.dart';
import '../../data/models/stock_level_data.dart';
import '../../data/repositories/stock_repository.dart';

enum _LotFilter { all, nearExpiry, expired, quarantined }

/// Every lot the clinic has received, from `GET /v1/batches`: supplier, date of
/// reception, DLC, status and what is still on hand. The traceability view: a
/// lot stays listed after it is used up.
class BatchListScreen extends StatefulWidget {
  const BatchListScreen({super.key});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  late Future<List<BatchData>> _future;
  _LotFilter _filter = _LotFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = getIt<StockRepository>().listBatches();
  }

  Future<void> _refresh() async {
    setState(() => _future = getIt<StockRepository>().listBatches());
    await _future;
  }

  bool _matches(BatchData b) {
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty &&
        !b.batchNumber.toLowerCase().contains(q) &&
        !b.productName.toLowerCase().contains(q) &&
        !b.supplierName.toLowerCase().contains(q)) {
      return false;
    }
    switch (_filter) {
      case _LotFilter.all:
        return true;
      case _LotFilter.nearExpiry:
        return b.isNearExpiry;
      case _LotFilter.expired:
        return b.isExpired;
      case _LotFilter.quarantined:
        return b.isQuarantined;
    }
  }

  /// Expired first, then soonest DLC; lots without a DLC last.
  static int _compare(BatchData a, BatchData b) {
    final da = a.daysToExpiry;
    final db = b.daysToExpiry;
    if (da == null && db == null) return a.batchNumber.compareTo(b.batchNumber);
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  int _count(List<BatchData> all, _LotFilter f) {
    switch (f) {
      case _LotFilter.all:
        return all.length;
      case _LotFilter.nearExpiry:
        return all.where((b) => b.isNearExpiry).length;
      case _LotFilter.expired:
        return all.where((b) => b.isExpired).length;
      case _LotFilter.quarantined:
        return all.where((b) => b.isQuarantined).length;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Lots'),
      body: FutureBuilder<List<BatchData>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const ListSkeleton();
          }
          if (snap.hasError) {
            return ErrorView(
              message: 'Impossible de charger les lots.',
              onRetry: _refresh,
            );
          }
          final all = snap.data ?? const <BatchData>[];
          if (all.isEmpty) {
            return const EmptyView(
              title: 'Aucun lot',
              message: 'Les lots apparaissent ici dès qu\'une commande est '
                  'réceptionnée avec un numéro de lot.',
              icon: Icons.inventory_outlined,
            );
          }
          final shown = all.where(_matches).toList()..sort(_compare);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xs,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      boxShadow: AppShadows.card,
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: AppTypography.body,
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un lot, un produit, un fournisseur',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.search,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                FilterChipRow<_LotFilter>(
                  selected: _filter,
                  onSelected: (f) =>
                      setState(() => _filter = f ?? _LotFilter.all),
                  options: [
                    FilterChipOption(
                      value: _LotFilter.all,
                      icon: Icons.inventory_outlined,
                      label: 'Tous (${_count(all, _LotFilter.all)})',
                    ),
                    FilterChipOption(
                      value: _LotFilter.nearExpiry,
                      icon: Icons.hourglass_top_outlined,
                      label:
                          'DLC proche (${_count(all, _LotFilter.nearExpiry)})',
                    ),
                    FilterChipOption(
                      value: _LotFilter.expired,
                      dotColor: AppColors.danger,
                      label: 'Périmés (${_count(all, _LotFilter.expired)})',
                    ),
                    FilterChipOption(
                      value: _LotFilter.quarantined,
                      dotColor: AppColors.warning,
                      label:
                          'Quarantaine (${_count(all, _LotFilter.quarantined)})',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (shown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: EmptyView(
                      title: 'Aucun lot',
                      message: 'Aucun lot ne correspond à cette recherche.',
                      icon: Icons.search_off_outlined,
                    ),
                  )
                else
                  for (var i = 0; i < shown.length; i++)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: AnimatedListItem(
                        index: i,
                        child: _LotCard(
                          batch: shown[i],
                          onTap: () => _LotSheet.show(context, shown[i]),
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

({String label, StatusTone tone, Color color}) _lotStatus(BatchData b) {
  if (b.isQuarantined) {
    return (label: 'Quarantaine', tone: StatusTone.danger, color: AppColors.danger);
  }
  if (b.isExpired) {
    return (label: 'Périmé', tone: StatusTone.danger, color: AppColors.danger);
  }
  if (b.isNearExpiry) {
    return (label: 'DLC proche', tone: StatusTone.warning, color: AppColors.warning);
  }
  if (b.isEmpty) {
    return (label: 'Épuisé', tone: StatusTone.neutral, color: AppColors.textSecondary);
  }
  return (label: 'Utilisable', tone: StatusTone.success, color: AppColors.success);
}

class _LotCard extends StatelessWidget {
  final BatchData batch;
  final VoidCallback onTap;
  const _LotCard({required this.batch, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = _lotStatus(batch);
    final days = batch.daysToExpiry;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWell,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  size: 22,
                  color: AppColors.navyHeader,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.supplierName.isEmpty
                          ? 'FOURNISSEUR INCONNU'
                          : batch.supplierName.toUpperCase(),
                      style: AppTypography.eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lot ${batch.batchNumber}',
                      style: AppTypography.cardTitle,
                    ),
                    Text(
                      batch.productName,
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(label: status.label, tone: status.tone),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceWell,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Fact(
                    label: 'EN STOCK',
                    value: '${batch.qtyOnHand}',
                    color: batch.isEmpty ? AppColors.textSecondary : null,
                  ),
                ),
                Expanded(
                  child: _Fact(
                    label: 'DLC',
                    value: batch.expiryDate == null
                        ? '—'
                        : AppDateFormatter.date(batch.expiryDate!),
                    color: batch.isExpired
                        ? AppColors.danger
                        : batch.isNearExpiry
                            ? AppColors.warning
                            : null,
                  ),
                ),
                Expanded(
                  child: _Fact(
                    label: 'REÇU LE',
                    value: batch.receivedAt == null
                        ? '—'
                        : AppDateFormatter.date(batch.receivedAt!),
                  ),
                ),
              ],
            ),
          ),
          if (days != null && !batch.isEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              days < 0
                  ? 'Périmé depuis ${-days} jour${-days > 1 ? 's' : ''}'
                  : days == 0
                      ? 'Expire aujourd\'hui'
                      : 'Expire dans $days jour${days > 1 ? 's' : ''}',
              style: AppTypography.caption.copyWith(
                color: days < 0
                    ? AppColors.danger
                    : days <= 30
                        ? AppColors.warning
                        : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Fact({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.eyebrow.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.bodyStrong.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// A lot in full: where it came from, where it is now, and (for the roles that
/// may move stock) what can be done with it.
class _LotSheet extends StatelessWidget {
  final BatchData batch;
  const _LotSheet({required this.batch});

  static Future<void> show(BuildContext context, BatchData batch) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _LotSheet(batch: batch),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _lotStatus(batch);
    final canManage = getIt<SessionStore>().hasPermission('inventory.manage');
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
                      Text(
                        'LOT ${batch.batchNumber}',
                        style: AppTypography.eyebrow,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        batch.productName,
                        style: AppTypography.sectionTitle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(label: status.label, tone: status.tone),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FormCard(
              title: 'Traçabilité',
              gap: AppSpacing.xs,
              children: [
                _SheetRow(
                  icon: Icons.local_shipping_outlined,
                  label: 'Fournisseur',
                  value: batch.supplierName.isEmpty ? '—' : batch.supplierName,
                ),
                _SheetRow(
                  icon: Icons.move_to_inbox_outlined,
                  label: 'Reçu le',
                  value: batch.receivedAt == null
                      ? '—'
                      : AppDateFormatter.dateTime(batch.receivedAt!),
                ),
                _SheetRow(
                  icon: Icons.event_busy_outlined,
                  label: batch.isExpired ? 'Périmé depuis le' : 'Expire le',
                  value: batch.expiryDate == null
                      ? 'Sans DLC'
                      : AppDateFormatter.date(batch.expiryDate!),
                  color: batch.isExpired
                      ? AppColors.danger
                      : batch.isNearExpiry
                          ? AppColors.warning
                          : null,
                ),
                _SheetRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Quantité en stock',
                  value: '${batch.qtyOnHand}',
                ),
                if (batch.isQuarantined)
                  const _SheetRow(
                    icon: Icons.block_outlined,
                    label: 'Statut',
                    value: 'En quarantaine : ne pas utiliser',
                    color: AppColors.danger,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _Where(batch: batch),
            if (canManage && !batch.isEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              const Text('ACTIONS SUR CE LOT', style: AppTypography.eyebrow),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (!batch.isQuarantined) ...[
                    Expanded(
                      child: _Action(
                        icon: Icons.remove_circle_outline,
                        label: 'Sortie',
                        route: Routes.stockIssueFor(batch.id),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: _Action(
                      icon: Icons.swap_horiz,
                      label: 'Transfert',
                      route: Routes.stockTransferFor(batch.id),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _Action(
                      icon: Icons.edit_outlined,
                      label: 'Ajuster',
                      route: Routes.stockAdjustFor(batch.id),
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
}

/// "Où est ce lot ?": the places that hold it, read from the stock rows.
class _Where extends StatelessWidget {
  final BatchData batch;
  const _Where({required this.batch});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StockLevelData>>(
      future: getIt<StockRepository>().listLevels(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final rows = (snap.data ?? const <StockLevelData>[])
            .where((r) => r.batchId == batch.id && r.qty > 0)
            .toList();
        if (snap.hasError) {
          return const Text(
            'Les emplacements n\'ont pas pu être chargés.',
            style: AppTypography.caption,
          );
        }
        if (rows.isEmpty) {
          return const Text(
            'Ce lot n\'est présent dans aucun emplacement.',
            style: AppTypography.caption,
          );
        }
        return FormCard(
          title: 'Où est ce lot ?',
          gap: AppSpacing.xs,
          children: [
            for (final r in rows)
              _SheetRow(
                icon: Icons.place_outlined,
                label: r.locationName,
                value: '${r.qty} ${r.unit}',
              ),
          ],
        );
      },
    );
  }
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _SheetRow({
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

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  const _Action({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceWell,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        onTap: () {
          // The router is taken before the sheet closes: the sheet's own
          // context is gone afterwards.
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          if (isTabRoute(route)) {
            router.go(route);
          } else {
            router.push(route);
          }
        },
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
