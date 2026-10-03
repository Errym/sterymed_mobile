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

part 'batch_list_screen_parts/lot_filter.dart';
part 'batch_list_screen_parts/where.dart';

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
